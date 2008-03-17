//-----------------------------------------------------------
// $Id$
//-----------------------------------------------------------
class IrcClient extends TcpLink
    config(IrcLib);

struct Hostmask
{
    var string Nick, User, Host;
};

struct IrcMessage
{
    var string Prefix;
    var string Command;
    var array<string> Params;
    var bool bFinalParamHasColon;
};

enum ELogLevel
{
    LL_Debug,
    LL_Notice,
    LL_Warning,
    LL_Error
};
var config ELogLevel LogLevel;

enum EIrcState
{
    IRCS_Disconnected,
    IRCS_Connecting,
    IRCS_Connected,
    IRCS_Registered
};
var EIrcState IrcState;

var int DefaultPort;

var string ServerHost;
var IpAddr ServerAddr;
var array<IrcChannel> Channels;
var string CurrentNick;

var config string NickName;
var config string UserName;
var config string RealName;

var config string VersionString;

var string NamesReplyUsers;

var config bool bThrottleEnable;
var config float ThrottleCommandPenalty;
var config float ThrottleMessagePenalty;
var config float ThrottleMaxPenalty;
var config int ThrottleMaxMessageQueue;

var float ThrottlePenalty;
var array<string> ThrottleQueue;

struct IrcEvent
{
    var string Command;
    var delegate<IrcEventDelegate> Handler;
};
var array<IrcEvent> Events;

delegate IrcEventDelegate(IrcMessage Message);

simulated function PostBeginPlay()
{
    // Core IRC functionality
    RegisterHandler(IrcClient_Handler_PING, "PING");
    RegisterHandler(IrcClient_Handler_433, "433");
    RegisterHandler(IrcClient_Handler_001, "001");
    RegisterHandler(IrcClient_Handler_NICK, "NICK");
    RegisterHandler(IrcClient_Handler_JOIN, "JOIN");
    RegisterHandler(IrcClient_Handler_PART, "PART");
    RegisterHandler(IrcClient_Handler_KICK, "KICK");
    RegisterHandler(IrcClient_Handler_353, "353");
    RegisterHandler(IrcClient_Handler_366, "366");

    // CTCP
    RegisterHandler(IrcClient_CTCPHandler, "PRIVMSG");
}

function Log(string Text, ELogLevel LL)
{
    if (LL >= LogLevel)
        `Log("IRC -- " $ Text);
}

function Connect(string Server, optional int ServerPort)
{
    ServerHost = Server;
    ServerAddr.Port = (ServerPort == 0 ? DefaultPort : ServerPort);
    Connect2();
}

function Connect2()
{
    Log("Resolving " $ ServerHost, LL_Notice);
    Resolve(ServerHost);
}

event ResolveFailed()
{
    Log("Failed to resolve host; retrying", LL_Warning);
    SetTimer(5, false, 'Connect2');
}

event Resolved(IpAddr Addr)
{
    if (Addr.Addr == 0)
    {
        ResolveFailed();
        return;
    }

    ServerAddr.Addr = Addr.Addr;
    Connect3();
}

function Connect3()
{
    if (LinkState >= STATE_Connecting)
        return;

    Log("Connecting to " $ IpAddrToString(ServerAddr), LL_Notice);

    LinkMode = MODE_Line;
    Log("BindPort() returned " $ BindPort(), LL_Debug);
    Log("Open() returned " $ Open(ServerAddr), LL_Debug);

    SetTimer(5, false, 'Connect3'); // probably not correct
}

event Opened()
{
    Log("Connected", LL_Notice);
    IrcState = IRCS_Connected;

    USER(UserName, "*", "*", RealName);
    NICK(NickName);
}

event Destroyed()
{
    Close();
}

event Closed()
{
    Log("Disconnected", LL_Notice);
    IrcState = IRCS_Disconnected;
    Destroy();
}

static function bool MatchString(string Pattern, string Str, optional bool bCaseSensitive = false)
{
    local int i, j;

    i = 0;
    j = 0;

    while (Len(Str) > j)
    {
        if (Mid(Pattern, i, 1) == "*")
        {
            do
                i++;
            until (Mid(Pattern, i, 1) != "*");

            if (Len(Pattern) <= i)
                return true;

            while (Len(Str) > j)
            {
                if (MatchString(Mid(Pattern, i), Mid(Str, j)))
                    return true;
                j++;
            }

            return false;
        }
        else if (Mid(Pattern, i, 1) != "?")
        {
            if (bCaseSensitive)
            {
                if (Mid(Pattern, i, 1) != Mid(Str, j, 1))
                    return false;
            }
            else
            {
                if (!(Mid(Pattern, i, 1) ~= Mid(Str, j, 1)))
                    return false;
            }
        }
        i++;
        j++;
    }

    while (Mid(Pattern, i, 1) == "*")
        i++;

    return Len(Pattern) <= i;
}

static function Split2(string Separator, string Str, out string LeftPart, out string RightPart)
{
    local int Pos;

    Separator = Left(Separator, 1);
    Pos = InStr(Str, Separator);
    if (Pos == -1)
    {
        LeftPart = Str;
        RightPart = "";
    }
    else
    {
        LeftPart = Left(Str, Pos);
        while (Mid(Str, Pos, 1) == Separator)
            Pos++;
        RightPart = Mid(Str, Pos);
    }
}

function IrcMessage ParseMessage(coerce string Message)
{
    local int i;
    local IrcMessage Result;
    local string Param;

    if (Left(Message, 1) == ":")
        Split2(" ", Mid(Message, 1), Result.Prefix, Message);
    else
        Result.Prefix = "";

    Split2(" ", Message, Result.Command, Message);

    for (i = 0; Len(Message) > 0; i++)
    {
        if (Left(Message, 1) == ":")
        {
            Result.Params[i] = Mid(Message, 1);
            Result.bFinalParamHasColon = true;
            break;
        }
        else
        {
            Split2(" ", Message, Param, Message);
            Result.Params[i] = Param;
        }
    }

    return Result;
}

function string MakeMessage(IrcMessage Message)
{
    local string Result;
    local int i;
    local string Param;

    if (Message.Prefix != "")
        Result $= ":" $ Message.Prefix $ " ";

    Result $= Message.Command;

    foreach Message.Params(Param, i)
    {
        if (i == Message.Params.Length - 1 && Message.bFinalParamHasColon)
            Result $= " :" $ Param;
        else
            Result $= " " $ Param;
    }

    return Result;
}

function SendMessage(IrcMessage Message)
{
    SendLine(MakeMessage(Message));
}

function Hostmask ParseHostmask(coerce string Str)
{
    local Hostmask Result;
    Split2("!", Str, Result.Nick, Str);
    Split2("@", Str, Result.User, Result.Host);
    return Result;
}

function string Timeleft()
{
}

function RegisterHandler(delegate<IrcEventDelegate> Handler, optional string Command)
{
    local IrcEvent E;
    E.Command = Command;
    E.Handler = Handler;
    Events.AddItem(E);
}

event ReceivedLine(string Line)
{
    Log("Recv: " $ Line, LL_Debug);
    ReceivedMessage(ParseMessage(Line));
}

function ThrottleMessage();

simulated function Tick(float DeltaTime)
{
    local IrcMessage Message;
    local int i;
    local string Str;

    if (!bThrottleEnable)
    {
        foreach ThrottleQueue(Str)
            SendText(Str);
        ThrottleQueue.Length = 0;
        return;
    }

    ThrottlePenalty = FMax(0, ThrottlePenalty - DeltaTime / WorldInfo.TimeDilation);

    if (ThrottleQueue.Length > ThrottleMaxMessageQueue)
    {
        i = 0;
        foreach ThrottleQueue(Str)
        {
            Message = ParseMessage(Str);
            if (Message.Command ~= "PRIVMSG")
                i++;

            if (i > ThrottleMaxMessageQueue)
            {
                for (i = ThrottleQueue.Length - 1; i >= 0; i--)
                {
                    Message = ParseMessage(ThrottleQueue[i]);
                    if (Message.Command ~= "PRIVMSG")
                        ThrottleQueue.Remove(i, 1);
                }
                ThrottleMessage();
                break;
            }
        }
    }

    while (ThrottleQueue.Length > 0 && ThrottlePenalty < ThrottleMaxPenalty)
    {
        if (ThrottleQueue.Length > ThrottleMaxMessageQueue)
        {
            ThrottleQueue.Length = 0;
            ThrottleMessage();
            continue;
        }
        Message = ParseMessage(ThrottleQueue[0]);
        if (Message.Command ~= "PRIVMSG")
            ThrottlePenalty += ThrottleMessagePenalty;
        else
            ThrottlePenalty += ThrottleCommandPenalty;
        SendText(ThrottleQueue[0]);
        ThrottleQueue.Remove(0, 1);
    }
}

function SendLine(string Line)
{
    Log("Send: " $ Line, LL_Debug);
    ThrottleQueue.AddItem(Line);
}

function IrcChannel AddChannel(string Channel)
{
    local IrcChannel C;

    if (GetChannel(Channel) == none)
    {
        C = new class'IrcChannel';
        C.Channel = Channel;
        C.Irc = self;
        Channels.AddItem(C);

        Log("Added channel" @ Channel, LL_Debug);
    }
    return Channels[Channels.Length - 1];
}

function RemoveChannel(string Channel)
{
    local int i;

    if (GetChannel(Channel, i) != none)
    {
        Channels.Remove(i, 1);
        Log("Removed channel" @ Channel, LL_Debug);
    }
}

function IrcChannel GetChannel(string Channel, optional out int Index)
{
    local IrcChannel C;
    local int i;

    foreach Channels(C, i)
    {
        if (C.Channel ~= Channel)
        {
            Index = i;
            return C;
        }
    }
    Index = -1;
    return none;
}

////////// IRC events

function ReceivedMessage(IrcMessage Message)
{
    local IrcEvent E;
    local delegate<IrcEventDelegate> Handler;

    foreach Events(E)
    {
        if (E.Command ~= Message.Command || E.Command == "")
        {
            Handler = E.Handler;
            Handler(Message);
        }
    }
}

function ReceivedCTCP(string Command, string Text, IrcMessage Message)
{
    local string Response;

    if (Command ~= "CLIENTINFO")
    {
        if (Text == "")
            Response = ":Supported tags: PING,VERSION,CLIENTINFO,ACTION - Use 'CLIENTINFO <tag>' for a description of each tag";
        else if (Text ~= "PING")
            Response = ":PING: Returns given parameters without parsing them";
        else if (Text ~= "VERSION")
            Response = ":VERSION: Returns the version of this client";
        else if (Text ~= "CLIENTINFO")
            Response = ":CLIENTINFO: With no parameters, lists supported CTCP tags, 'CLIENTINFO <tag>' describes <tag>";
        else if (Text ~= "TIME")
            Response = ":TIME: Returns the current local time";
        else if (Text ~= "ACTION")
            Response = ":ACTION: Used to describe actions, generates no reply";
        else
        {
            Response = ":Unsupported tag" @ Command;
            Command = "ERRMSG";
        }
    }
    else if (Command ~= "PING")
        Response = Text;
    else if (Command ~= "VERSION")
        Response = VersionString;

    if (Response != "")
        CTCPReply(ParseHostmask(Message.Prefix).Nick, Command @ Response);
}

function Registered()
{
    // Use this function to perform actions when we have connected
}

////////// IRC handlers

function IrcClient_Handler_PING(IrcMessage Message)
{
    Message.Command = "PONG";
    SendMessage(Message);
}

function IrcClient_Handler_001(IrcMessage Message) // this happens when we're registered
{
    if (IrcState < IRCS_Registered)
    {
        CurrentNick = Message.Params[0];
        Registered();
    }
}

function IrcClient_Handler_433(IrcMessage Message) // ERR_NICKNAMEINUSE
{
    if (IrcState < IRCS_Registered)
    {
        Log("Nick" @ Message.Params[1] @ "in use; trying" @ Message.Params[1] $ "`", LL_Warning);
        NICK(Message.Params[1] $ "`");
    }
    else
    {
        Log("Nick" @ Message.Params[1] @ "in use", LL_Warning);
    }
}

function IrcClient_Handler_NICK(IrcMessage Message) // RPL_ENDOFMOTD
{
    if (ParseHostmask(Message.Prefix).Nick == CurrentNick)
    {
        CurrentNick = Message.Params[0];
    }
}

function IrcClient_Handler_JOIN(IrcMessage Message)
{
    if (ParseHostmask(Message.Prefix).Nick == CurrentNick)
        AddChannel(Message.Params[0]);
}

function IrcClient_Handler_PART(IrcMessage Message)
{
    if (ParseHostmask(Message.Prefix).Nick == CurrentNick)
        RemoveChannel(Message.Params[0]);
}

function IrcClient_Handler_KICK(IrcMessage Message)
{
    if (ParseHostmask(Message.Prefix).Nick == CurrentNick)
        RemoveChannel(Message.Params[0]);
}

function IrcClient_Handler_353(IrcMessage Message) // RPL_NAMEREPLY
{
    NamesReplyUsers $= Message.Params[3] $ " ";
}

function IrcClient_Handler_366(IrcMessage Message) // RPL_ENDOFNAMES
{
    local IrcChannel C;

    C = GetChannel(Message.Params[1]);
    if (C != none)
        C.ProcessUserList(NamesReplyUsers);
    NamesReplyUsers = "";
}

function IrcClient_CTCPHandler(IrcMessage Message)
{
    local string Command, Text;

    Text = Message.Params[1];

    if (Left(Text, 1) != Chr(1))
        return;

    if (Right(Text, 1) == Chr(1))
        Text = Mid(Text, 1, Len(Text) - 2);
    else
        Text = Mid(Text, 1);

    Split2(" ", Text, Command, Text);

    ReceivedCTCP(Command, Text, Message);
}

////////// IRC messages

function PASS(string password)
{
    SendLine("PASS" @ password);
}

function NICK(string nick)
{
    SendLine("NICK" @ nick);
}

function USER(string user, string host, string server, string real)
{
    UserName = user;
    RealName = real;
    SendLine("USER" @ user @ host @ server @ ":" $ real);
}

function JOIN(string chans, optional string keys)
{
    SendLine("JOIN" @ chans $ (Len(keys) > 0 ? " " $ keys : ""));
}

function PART(string chans)
{
    SendLine("PART" @ chans);
}

function MODE(string target, string mode)
{
    SendLine("MODE" @ target @ mode);
}

function TOPIC(string chan, optional string newtopic)
{
    SendLine("TOPIC" @ chan $ (Len(newtopic) > 0 ? " " $ newtopic : ""));
}

function INVITE(string nick, string chan)
{
    SendLine("INVITE" @ nick @ chan);
}

function KICK(string chan, string user, optional string comment)
{
    SendLine("KICK" @ chan @ user $ (Len(comment) > 0 ? " :" $ comment : ""));
}

function PRIVMSG(string target, string text)
{
    SendLine("PRIVMSG" @ target @ ":" $ text);
}

function NOTICE(string target, string text)
{
    SendLine("NOTICE" @ target @ ":" $ text);
}

function QUIT(optional string message)
{
    SendLine("QUIT" $ (Len(message) > 0 ? " :" $ message : ""));
}

function CTCPRequest(string target, string text)
{
    PRIVMSG(target, Chr(1) $ text $ Chr(1));
}

function CTCPReply(string target, string text)
{
    NOTICE(target, Chr(1) $ text $ Chr(1));
}

////////// Useful functions

const IrcWhite = 0;
const IrcBlack = 1;
const IrcNavy = 2;
const IrcGreen = 3;
const IrcRed = 4;
const IrcBrown = 5;
const IrcPurple = 6;
const IrcOrange = 7;
const IrcYellow = 8;
const IrcLime = 9;
const IrcTeal = 10;
const IrcCyan = 11;
const IrcBlue = 12;
const IrcPink = 13;
const IrcGrey = 14;
const IrcLtGrey = 15;

function string IrcBold(coerce string Text)
{
    return Chr(2) $ Text $ Chr(2);
}

function string IrcUnderline(coerce string Text)
{
    return Chr(31) $ Text $ Chr(31);
}

function string IrcReverse(coerce string Text)
{
    return Chr(22) $ Text $ Chr(22);
}

function string IrcColor(coerce string Text, byte ForeColor, optional byte BackColor = 255)
{ // TODO: make it better
    return Chr(3) $ Right("0" $ ForeColor, 2) $ (BackColor == 255 ? "" : "," $ Right("0" $ BackColor, 2)) $
        Text $ Chr(3);
}

function string IrcResetFormat()
{
    return Chr(15);
}

defaultproperties
{
    LogLevel=LL_Notice

    DefaultPort=6667
    NickName="ut3irc"
    UserName="ut3irc"
    RealName="UT3 IRC"

    bThrottleEnable=true
    ThrottleCommandPenalty=1.0
    ThrottleMessagePenalty=2.0
    ThrottleMaxPenalty=10.0
    ThrottleMaxMessageQueue=30

    VersionString="UT3 IrcLib - SVN $Rev$"
}

