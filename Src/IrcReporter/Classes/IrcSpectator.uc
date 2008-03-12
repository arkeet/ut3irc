//-----------------------------------------------------------
// $Id$
//-----------------------------------------------------------
class IrcSpectator extends UTPlayerController;

var IrcReporter Reporter;

reliable client event TeamMessage(PlayerReplicationInfo PRI, coerce string S, name Type, optional float MsgLifeTime)
{
    if (PRI != PlayerReplicationInfo)
        Reporter.TeamMessage(PRI, S, Type, MsgLifeTime);
}

event PreClientTravel()
{
    Reporter.Log(self @ "PreClientTravel", LL_Debug);
}

reliable client event ReceiveLocalizedMessage(class<LocalMessage> Message, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
    Reporter.ReceiveLocalizedMessage(Message, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject);
}

simulated function PostBeginPlay()
{
    if (!bDeleteMe && !bIsPlayer && (WorldInfo.NetMode != NM_Client))
        InitPlayerReplicationInfo();

    if (PlayerReplicationInfo != None)
        PlayerReplicationInfo.bOutOfLives = true;
}

function InitPlayerReplicationInfo()
{
    Super.InitPlayerReplicationInfo();
    `Log("___________ InitPlayerReplicationInfo");
    PlayerReplicationInfo.PlayerName = "IRC";
    PlayerReplicationInfo.bIsSpectator = true;
    PlayerReplicationInfo.bOnlySpectator = true;
    PlayerReplicationInfo.bOutOfLives = true;
    PlayerReplicationInfo.bWaitingPlayer = false;
}

defaultproperties
{
    bIsPlayer=false
    RemoteRole=ROLE_AutonomousProxy // For some reason this is required to make it not crash. gg epic :(
}
