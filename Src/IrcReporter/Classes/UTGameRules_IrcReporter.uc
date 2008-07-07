//-----------------------------------------------------------
//
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
