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

