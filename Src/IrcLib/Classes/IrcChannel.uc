//-----------------------------------------------------------
// $Id$
//-----------------------------------------------------------
class IrcChannel extends Object;

var string ModeChars;

struct ChannelUser
{
    var string Nick;
    var string Mode;
};

var IrcClient Irc;

var string Channel;
var string Topic;
var array<ChannelUser> Users;

function ProcessUserList(string UserList)
{
    local string User;
    local ChannelUser U;

    Users.Length = 0;

    Irc.Log("Begin user list for" @ Channel, LL_Debug);
    while (Len(UserList) > 0)
    {
        Irc.Split2(" ", UserList, User, UserList);
        for (U.Mode = ""; Len(User) > 0 && InStr(ModeChars, Left(User, 1)) >= 0; User = Mid(User, 1))
        {
            U.Mode $= Left(User, 1);
        }
        U.Nick = User;
        Irc.Log("- " $ "(" $ (U.Mode == "" ? " " : U.Mode) $ ")" $ U.Nick, LL_Debug);
    }
    Irc.Log("End user list", LL_Debug);
}

function SendMessage(string Text)
{
    Irc.PRIVMSG(Channel, Text);
}

defaultproperties
{
    ModeChars="@+%~"
}
