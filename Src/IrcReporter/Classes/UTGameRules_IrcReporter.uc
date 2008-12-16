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
class UTGameRules_IrcReporter extends GameRules;

var IrcReporter Reporter;

simulated function PostBeginPlay()
{
    local IrcReporter R;

    foreach AllActors(class'IrcReporter', R)
    {
        Reporter = R;
        Reporter.GameRules = self;
        return;
    }
    if (Reporter == none)
        Destroy();
}

// These may have some use later on.

function bool HandleRestartGame()
{
    Reporter.Log("GameRules - HandleRestartGame", LL_Debug);
    return super.HandleRestartGame();
}

function bool CheckEndGame(PlayerReplicationInfo Winner, string Reason)
{
    Reporter.Log("GameRules - CheckEndGame" @ Winner @ Reason, LL_Debug);
    Reporter.GameEndReason = Reason;
    return super.CheckEndGame(Winner, Reason);
}

function bool OverridePickupQuery(Pawn Other, class<Inventory> ItemClass, Actor Pickup, out byte bAllowPickup)
{
    Reporter.Log("GameRules - OverridePickupQuery" @ Other @ ItemClass @ Pickup, LL_Debug);
    return super.OverridePickupQuery(Other, ItemClass, Pickup, bAllowPickup);
}

function bool PreventDeath(Pawn Killed, Controller Killer, class<DamageType> DamageType, vector HitLocation)
{
    Reporter.Log("GameRules - PreventDeath" @ Killed @ Killer @ DamageType, LL_Debug);
    return super.PreventDeath(Killed, Killer, DamageType, HitLocation);
}

function ScoreObjective(PlayerReplicationInfo Scorer, Int Score)
{
    Reporter.Log("GameRules - ScoreObjective" @ Scorer @ Score, LL_Debug);
    super.ScoreObjective(Scorer, Score);
}

function ScoreKill(Controller Killer, Controller Killed)
{
    Reporter.Log("GameRules - ScoreKill" @ Killer @ Killed, LL_Debug);
    super.ScoreKill(Killer, Killed);
}

function NetDamage(int OriginalDamage, out int Damage, pawn Injured, Controller InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
    Reporter.Log("GameRules - NetDamage" @ OriginalDamage @ Injured @ InstigatedBy @ DamageType, LL_Debug);
    super.NetDamage(OriginalDamage, Damage, Injured, InstigatedBy, HitLocation, Momentum, DamageType);
}

defaultproperties
{
}

