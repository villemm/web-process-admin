#Copyright ---- Ville Maanpaa 12-19-2006
#Run this server from command line:
#ruby auto_palvelin.rb
#then run clients from command prompt from as many machines as needed:
#ruby -e "require 'net/http'; eval(Net:: HTTP.new('10.65.5.152', 11113).get('/client_code').body);"
#then point FIREFOX at:
#http://localhost:11113
#BE CAREFUL, THIS PROGRAM CAN EXECUTE ANY COMMAND


require 'rubygems'
require 'htmlentities'
require 'gserver'
require 'cgi'
require 'rinda/ring'        # for RingServer
require 'rinda/tuplespace'  # for TupleSpace

##platform dependent commands##
#ps_command=''

$stdout.sync = true
$stderr.sync = true

class Palvelin < GServer

   def initialize(port=11113, *args)
     runRingServer
     super(port, *args)
   end
   def runRingServer
     eval("DRb.start_service;Rinda::RingServer.new (Rinda::TupleSpace.new);@ring_server = Rinda::RingFinger.primary;@ring_server.write( [:name, :TupleSpace, Rinda::TupleSpace.new, 'Tuple Space'], Rinda::SimpleRenewer.new );")
   end
   
   def serve(io)
     @statusok="HTTP/1.1 200 OK\nAccept-Language: en\n\n" #<meta Content-type: text/html\n\nEncoding: ISO-8859-1\n\n><?xml version='1.0' encoding='UTF-8'?>"
     @execform="<p>Execute command<form action = execute><input
           type=text name='command'><input type=submit
           value=execute></form></p>"   

    begin
     message = io.gets.chomp
     log(message)
     case message
       when /client_code/
         # puts rindaClient
         io.puts(@statusok  + rindaClient)
       when /textwcs/
        io.puts css
       when /execute/
        execute(io, message)
       when /hosts/
        hosts(io, message)
       when /kill_restart/
        kill_restart(io, message)
      else
         #io.puts(@statusok + @execform + Time.new.to_s + ' -- '+ message +' -- Unknown command' )
         io.puts(@statusok  + '<meta http-equiv="refresh" content="1;url=/hosts">' + Time.new.to_s)
     end
    rescue
     io.puts(@statusok + 'Error: ' + $!)
    end
   end

  def hosts(io, message)
        DRb.start_service
        ring_server = Rinda::RingFinger.primary
        ts_service = ring_server.read([:name, :TupleSpace, nil, nil])[2]
        tuplespace = Rinda:: TupleSpaceProxy.new(ts_service)     
        hosts = tuplespace.read_all([:host, nil])
        puts hosts.inspect

        counter=1
        tabscontent="<ul class='tabs'>"
        borderside = 'right'
        hosts.each do |host|
               if (counter % 2) == 1
                 tabscontent << "<li style='border-#{borderside}: 1px solid #194367;'>"
                 if borderside == 'right'
                  borderside = 'left'                 
                 else
                  borderside = 'right'                 
                 end
               else
                 tabscontent << "<li>"
               end
               tabscontent << "<a href=\"#\" onClick='return showPane(\"pane#{ counter.to_s}\", this)' id='tab#{counter.to_s}'>#{host[1]}</a>"
               tabscontent << "</li>"
               counter = counter + 1
        end
        tabscontent << "</ul>     <div class='tab-panes'>"
        counter=1
        hosts.each do |host|
          tabscontent << "<div class='content' id='pane#{counter.to_s}'>"
          tabscontent << '<p>'+"#{host[1]} Execute command(ls -la /cygdrive/c etc.):<input type=text name=command id='new-command#{counter}'><input type=hidden name=host value=#{host[1]}><input type=button value ='execute' onclick='executeCommand(\"#{host[1]}\",\"#{counter}\")'>"+'</p>'
          tabscontent << "<input type=button value ='ProcessAdmin' onclick='loadXMLDoc(\"/execute?command=ps&host=#{host[1]}\",\"#{counter}\")'>"
          tabscontent << "<div id='command-list#{counter}'></div>"
          tabscontent << "<div id='printDiv#{counter}'></div>"          
          tabscontent << '</div>'          
          counter = counter + 1
        end  
#        puts  tabs(tabscontent)
        io.puts xmlhttprequest
        io.puts tabs(tabscontent)
 
  end

 def kill_restart(io, message)
   begin
     re = /\/(\w+)(.*)\s+\w+/
     m = re.match (message)
     log m[2]
     pidArray = m[2].scan(/\d*/)
     pidArray.delete("")
     log pidArray.inspect
     result=""
     pidArray.each do |pid|
       if(message =~ /\?restart/)
         psdetail = `ps -Wa -p #{pid}`
         log psdetail
#          command = /\/.*/.match(psdetail)
         command = /C\:.*/.match(psdetail)
         result << `kill -9 --force #{pid}`
         #sleep 3
         log command.to_s
         `start /min #{command.to_s}`
       else
         result << `kill -9 --force #{pid}`
       end
     end
     io.puts(@statusok + "Processed " + result.to_s )
   end
   rescue
     io.puts(@statusok + 'Error: ' + $!)
   end
 #end

   def execute(io, message)
    re = /\?(\w+)(.*)\s+\w+/
    m = re.match(message)
    command = m[2].split('=')[1].split('&')[0]
    command.gsub!("+", " ")
    command.gsub!('%20', " ")
    puts "THE COMMAND IS: " + command
    #puts m[0]
    hostname=m[2].split('=')[2]

    DRb.start_service
    ring_server = Rinda::RingFinger.primary    
    ts_service = ring_server.read([:name, :TupleSpace, nil, nil])[2]
    tuplespace = Rinda:: TupleSpaceProxy.new(ts_service)
    tuplespace.write ([:"task-#{hostname}", command])
    puts "wrote " + "task-#{hostname}" + command
    puts tuplespace.read([:"result-#{hostname}", nil])[1]
    io.puts(@statusok + tuplespace.take ([:"result-#{hostname}", nil])[1])
   end

  def rindaClient
    clientcode = <<RINDA_CLIENT_CODE
        require 'rinda/ring'        # for RingFinger
        require 'rinda/tuplespace'  # for TupleSpaceProxy
        require 'socket'
        
        $stdout.sync = true
        $stderr.sync = true
        
        class RindaClient
          def initialize
            myhostname=Socket::gethostname
            DRb.start_service
            ring_server = Rinda::RingFinger.primary
            ts_service = ring_server.read([:name, :TupleSpace, nil, nil])[2]
            tuplespace = Rinda::TupleSpaceProxy.new (ts_service)
            allhosts = tuplespace.read_all([:host, nil])
            puts allhosts
            if !(allhosts.to_s =~ /\#\{Socket::gethostname}/)
              tuplespace.write([:host, Socket::gethostname])
            end        
            task="task-" + myhostname
            while 1
                puts "ready to take command"
                command = tuplespace.take([:"\#\{task}", nil])[1]
                puts "we got: " + command
                if command =~ /ps/
                  result = handlePScommand
                elsif command =~ /kill/
		  begin
                  	`\#\{command}`
                  	result = handlePScommand
		  rescue
			command.gsub!('kill','pskill')
			`\#\{command}`
		  end
                else
                  result = `\#\{command}`        
                end      
                puts "we ran command \#\{command}"        
                if result == ""
                  result = "executed"
                end
                begin
                  result.gsub!("\\n","<br>")
                  tuplespace.write([:"result-\#\{myhostname}", result])
                  puts "we wrote into result-\#\{myhostname}: " + result
                rescue
                  tuplespace.write([:"result-\#\{myhostname}", $!.to_s])   
                end
            end
          end  
          
            def handlePScommand
if PLATFORM =~ /win32/
  begin
  if `pwd` =~ /\//
    ps_command='ps -aW'
  else
      ps_command='pslist'
    end
    rescue
    ps_command='pslist'
    end
else
  ps_command='ps -auxc'
end
puts ps_command
                    status = `\#\{ps_command}`
                    form= "<table><tr><td></td><td>Processes</td></tr>"
                    statuslines=status.split("\\n")
                    statuslines.delete_at(0)
                    if ps_command =~ /pslist/
                      statuslines= statuslines[9..-1]
                    end
                    statuslines.each do |line|
                     if ps_command =~ /pslist/
                     form << "<tr><td><center><input type=button value ='kill' onclick='loadXMLDoc(\\"/execute?command=kill+-f+\#\{ line.split()[1]}&host=\#\{Socket::gethostname}\\",\\"\#\{Socket::gethostname}\\")'></td><td>"              
                     
                     else
                      form << "<tr><td><center><input type=button value ='kill' onclick='loadXMLDoc(\\"/execute?command=kill+-f+\#\{ line.split()[0]}&host=\#\{Socket::gethostname}\\",\\"\#\{Socket::gethostname}\\")'></td><td>"              
                     end
                      form << line
                      form << "</td></tr>"           
                    end
                    form << "</table>"
                    form.sub!("<input type= checkbox id= 'PID' name= 'PID'>","")
                    form.gsub!("\\n","")
                    10.times do
                     form.gsub!("  "," ")
                    end        
                    result = form
            end
        end
        r=RindaClient.new

RINDA_CLIENT_CODE

  end
 
  def tabs(content_divs)
  tabstext = <<TABS
<head>
    <meta http-equiv="Pragma" content="no-cache">
    <title>Nexa Host Admin</title>
    <link rel="stylesheet" href="textwcs.css" type="text/css">
    <style type="text/css">
    <!--
    .tabs {position:relative; left: 0; top: 3; border:1px solid #194367; height: 27px; width: 890; margin: 0; padding: 0; background:#C0D9DE; overflow:hidden }
    .tabs li {display:inline}
    .tabs a:hover, .tabs a.tab-active {background:#fff;}
    .tabs a  { height: 27px; font:11px verdana, helvetica, sans-serif;font-weight:bold;
        position:relative; padding:6px 10px 10px 10px; margin: 0px -4px 0px 0px; color:#2B4353;text-decoration:none; }
    .tab-container { background: #fff; border:0px solid #194367; height:320px; width:900px}
    .tab-panes { margin: 3px; border:1px solid #194367; height:1420px}
    div.content { padding: 5px; }
    // -->
    </style>

    <script language="JavaScript1.3">
    var panes = new Array();
    
    function setupPanes(containerId, defaultTabId) {
      // go through the DOM, find each tab-container
      // set up the panes array with named panes
      panes[containerId] = new Array();
      var maxHeight = 0; var maxWidth = 0;
      var container = document.getElementById(containerId);
      var paneContainer = container.getElementsByTagName("div")[0];
      var paneList = paneContainer.childNodes;
      for (var i=0; i < paneList.length; i++ ) {
        var pane = paneList[i];
        if (pane.nodeType != 1) continue;
        panes[containerId][pane.id] = pane;
        pane.style.display = "none";
      }
        document.getElementById(defaultTabId).onclick();
    }
    
    function showPane(paneId, activeTab) {
      // make tab active class
      // hide other panes (siblings)
      // make pane visible
      
        for (var con in panes) {
        activeTab.blur();
        activeTab.className = "tab-active";
        if (panes[con][paneId] != null) { // tab and pane are members of this container
          var pane = document.getElementById(paneId);
          pane.style.display = "block";
          var container = document.getElementById(con);
          var tabs = container.getElementsByTagName("ul")[0];
          var tabList = tabs.getElementsByTagName("a")
          for (var i=0; i<tabList.length; i++ ) {
            var tab = tabList[i];
            if (tab != activeTab) tab.className = "tab-disabled";
          }
          for (var i in panes[con]) {
            var pane = panes[con][i];
            if (pane == undefined) continue;
            if (pane.id == paneId) continue;
            pane.style.display = "none"
          }
        }
      }
      return false;    
    }    
    </script>
</head>
<body onload='setupPanes("container1", "tab1");'>
<div class="tab-container" id="container1">
     #{content_divs}
     </div>
</div>
TABS

  end
  def xmlhttprequest
   xhr = <<XMLHTTPREQUEST
<script type="text/javascript">
var req;
hostnum="";
function IsNumeric(sText)

{
   var ValidChars = "0123456789.";
   var IsNumber=true;
   var Char;
   for (i = 0; i < sText.length && IsNumber == true; i++)
      {
      Char = sText.charAt(i);
      if ( ValidChars.indexOf(Char) == -1)
         {
         IsNumber = false;
         }
      }
   return IsNumber;  
   }
function loadXMLDoc(url, _hostnum) {
    //url= "/textwcs";
    hostnum = _hostnum;
    if(!IsNumeric(hostnum)) { //finding correct hostnum since it was set as name instead of number
          var container = document.getElementById("container1");
          var tabs = container.getElementsByTagName ("ul")[0].childNodes;          
          for (var i=0; i < tabs.length; i++ ) {
            tabname = tabs[i].getElementsByTagName("a")[0].innerHTML;
            if(tabname==hostnum){
              hostnum = i+1;
            }
          }
          if(!IsNumeric(hostnum)) { //we couldnt find it so we just set to 1
            hostnum =1;
          }
    }
    if (window.XMLHttpRequest ) {
      req = new XMLHttpRequest();
    } else if (window.ActiveXObject) {
      req = new ActiveXObject("Microsoft.XMLHTTP");
    }
    req.onreadystatechange = processReqChange;
    req.open ("GET", url, true);
    req.send (null);
}
function processReqChange() {
  if (req.readyState == 4) {
    if (req.status == 200) {
      printDiv = document.getElementById ('printDiv'+hostnum);        
      part=req.responseText //.split('<form action = kill_restart>')[0] + req.responseText.split('<form action = kill_restart>')[1]
      //alert(part);
      //printDiv.innerHTML = req.responseText ;
      printDiv.innerHTML = part;
    }
  }
}
function executeCommand(hostname, _hostnum) {
 
  commandElement = document.getElementById ('new-command'+_hostnum);
  loadXMLDoc("/execute?command="+ commandElement.value + "&host=" + hostname, _hostnum);
  commandList = document.getElementById ('command-list'+_hostnum);
  clistText = commandList.innerHTML;
  clistText = clistText.split('</div>')[0];
  command=commandElement.value.replace(' ', '+');
  if(commandList.innerHTML.indexOf(command)==-1) {
    commandList.innerHTML = clistText + '<input type=button value ="' + command.replace ('+', ' ') +'" onclick=loadXMLDoc(\"/execute?command=' + command + '&host=' + hostname +'\",\"' + _hostnum +'\")>' +'</div>';   
  }
}
</script>
XMLHTTPREQUEST
 
  end
  def css

css = <<CSS
/*light blue - #6699CC
  dark blue - #003366
  link dark blue - #194367
  link green - #336666  
  orange - #FEAD33
  green - #336666
*/
/* eliminate everything above */

body        { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; }
li        { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; }
ol        { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; }
ul        { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; }
td        { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; }
td.menu    { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; width:144; background-color:#d7d7d7; vertical-align : top; text-align : left; }
td.newsbox    { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; background-color:#e0e0e0; padding-top: 4px; padding-bottom: 4px; padding-right: 4px; padding-left: 4px; vertical-align : top; text-align : left; border-top: double 4px #999999; border-left: double 4px #666666; border-bottom: double 4px #666666; border-right: double 4px #999999; }
td.wg { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; color:#ffffff; background-color:#048396; text-align:left; }
/*
For websmart code examples
*/
td.toplogo {font-size: 88px; font-family: Garamond; line-height: 50pt;  letter-spacing: -.1in;  font-weight: bold; color:#0865AA; background-color:#ffffff; align: left; vertical-align: bottom;  }
td.topsub {font-size: 18px; font-family: Georgia; line-height: 22pt; font-weight: bold; color:#0865AA; background-color:#ffffff; align: left; vertical-align: bottom; }
th {background-color:#048396; color:#000000;}
th.centered {text-align: center;}

table.newsbox {width : 223px; border-collapse: separate;}

/* Accomodates New link style for grey sides */
td.header{background-color:#6699CC; font-size: 13px; font-family: Verdana,Arial,Helvetica,sans-serif; font-weight:bold; color:#003366;}
td.side{height="14"}

a    { font-size: 12px; font-weight:bold; font-family: Verdana,Arial,Helvetica,sans-serif; color:#194367; text-decoration:underline; }
a.blue    { color:#6699cc; }
a.menu    { color:#336666; font-size: 10px; font-weight:bold; text-indent : 3px; text-decoration:none;}
a.news    { font-size: 10px; font-family: Verdana,Arial,Helvetica,sans-serif; color:#fead33; text-decoration:none; }
a.thtag { color:#FFFFFF; text-decoration:none; }

/* New link style for grey sides */
a.sidelink{ font-size: 11px; font-family: Verdana,Arial,Helvetica,sans-serif; font-weight:normal; color:#003366; text-decoration:none; }
a.sidelink:hover{font-size: 11px; font-family: Verdana,Arial,Helvetica,sans-serif; font-weight:bold; color:#003366; text-decoration:none;}

/* Links for tech eval mail out */
a.bodylink{ font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; font-weight:bold; color:#194367; text-decoration:none; }
a.bodylink:hover{font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; font-weight:bold; color:#048396; text-decoration:none;}
a.bodylinkl{ font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; font-weight:bold; color:#194367; text-decoration:none; }
a.bodylinkl:hover{ font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; font-weight:bold; font-style:italic; color:#048396; text-decoration:none;}

p        { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; }
li        { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; }
p.title    { font-size: 16px; color:#6699cc; text-align:center; font-weight:bold; }
p.smlight    { font-size: 10px; font-family: Verdana,Arial,Helvetica,sans-serif;}
p.news    { font-size: 10px; font-family: Verdana,Arial,Helvetica,sans-serif;}
p.kbheader    { font-size: 14px; font-family: Verdana,Arial,Helvetica,sans-serif; color:#777777; font-weight:bold; }
p.kbgray    { font-size: 14px; font-family: Verdana,Arial,Helvetica,sans-serif; color:#777777; }
p.kbtext    { font-size: 12px; font-family : "Courier New", Courier, monospace; }
p.demoexp    { font-size: 11px; font-family: Verdana,Arial,Helvetica,sans-serif; }



/* used for the | characters that are used for separation*/
.divider    { font-size: 10px; font-weight:bold; }
.code        { font-size: 12px; font-family: Courier; color:#800000; }
.file        { font-size: 12px; color:#800000; font-style:italic; }
.news     { font-size: 12px; font-family: Verdana,Arial,Helvetica,sans-serif; font-weight:bold;}

.err    { font-family:Arial; font-size:10pt; color:#FF0000; background-color:#FFFF00; }
input.err    { font-family:Arial; font-size:10pt; color:#000000; background-color:#AAEEEE; }

.bar {
    font-family: Verdana, Arial, Helvetica, sans-serif;
    font-size: 12px;
    color: #FFFFFF;
    background-color: #597583;
    height: 20px;

}

.text {
    font-family: Verdana, Arial, Helvetica, sans-serif;
    font-size: 12px;
    color: #666666;
    text-align: center;
}

A.text:link    {color:#666666; text-decoration:none;}
A.text:visited {color:#666666; text-decoration:none;}
A.text:active  {color:#81AFC6; text-decoration:none;}
A.text:hover   {color:#81AFC6; text-decoration:none;}

.text2 {
    font-family: Verdana, Arial, Helvetica, sans-serif;
    font-size: 12px;
    color: #FFFFFF;
}

A.text2:link    {color:#FFFFFF; text-decoration:none;}
A.text2:visited {color:#FFFFFF; text-decoration:none;}
A.text2:active  {color:#CCCCCC; text-decoration:none;}
A.text2:hover   {color:#CCCCCC; text-decoration:none;}

.altcol1 {
    font-family: Verdana, Arial, Helvetica, sans-serif;
    font-size: 12px;
    color: #666666;
    background-color: #EEEEEE;

}
.altcol2 {
    font-family: Verdana, Arial, Helvetica, sans-serif;
    font-size: 12px;
    color: #666666;
    background-color: #CCCCCC;
}

.highlight {
    font-family: Verdana, Arial, Helvetica, sans-serif;
    font-size: 12px;
    color: #666666;
    background-color: #FFFFAA;
}

.cathead {
    font-family: Verdana, Arial, Helvetica, sans-serif;
    font-size: 14px;
    color: #000000;
    font-weight: bold;
    text-align: center;
    text-decoration: underline;
}
CSS
  end
end

#######################



server = Palvelin.new
server.audit=true
server.audit = true                  # Turn logging on.
server.start
server.join

