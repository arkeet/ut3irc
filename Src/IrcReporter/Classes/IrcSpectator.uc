/*
   Copyright (C) 2008 Adrian Keet.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this program; if not, write to the Free Software Foundation, Inc.,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.  */

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
    PlayerReplicationInfo.bAdmin = true;
}

defaultproperties
{
    bIsPlayer=false
    RemoteRole=ROLE_AutonomousProxy // For some reason this is required to make it not crash. gg epic :(
}
