//-----------------------------------------------------------
// $Id$
//-----------------------------------------------------------
class ReporterChannelConfig extends Object
    perobjectconfig
    config(IrcReporter);

var string Channel;

var config bool bEnableSay;
var config bool bRequireSayCommand;

var config bool bSetTopic;
var config string TopicFormat;
var config string Motd;

struct MessageFilter
{
    var name MessageType;
    var bool bShow;
};
var config array<MessageFilter> MessageTypes;

defaultproperties
{
    bEnableSay=true
    bRequireSayCommand=true

    bSetTopic=false
    TopicFormat=""
    Motd=""
}
