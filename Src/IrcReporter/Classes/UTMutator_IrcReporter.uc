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
class UTMutator_IrcReporter extends UTMutator;

var IrcReporter Reporter;

function PostBeginPlay()
{
    local IrcReporter R;

    if (Reporter == none)
    {
        foreach AllActors(class'IrcReporter', R)
        {
            Reporter = R;
            break;
        }
    }

    if (Reporter == none)
    {
        Reporter = Spawn(class'IrcReporter');
    }
}

function GetSeamlessTravelActorList(bool bToEntry, out array<Actor> ActorList)
{
    ActorList.AddItem(self);
    ActorList.AddItem(Reporter);
    ActorList.AddItem(Reporter.ReporterSpectator);
    ActorList.AddItem(Reporter.GameRules);

    if (NextMutator != None)
    {
        NextMutator.GetSeamlessTravelActorList(bToEntry, ActorList);
    }
}

function NotifyLogin(Controller Entering)
{
    super.NotifyLogin(Entering);
    if (Reporter != none)
    {
        Reporter.NotifyLogin(Entering);
    }
}

function NotifyLogout(Controller Exiting)
{
    super.NotifyLogout(Exiting);
    if (Reporter != none)
    {
        Reporter.NotifyLogout(Exiting);
    }
}

defaultproperties
{
}

