/*
*      Copyright (C) 2012-2013 Team XBMC
*      http://www.xbmc.org
*
*  This Program is free software; you can redistribute it and/or modify
*  it under the terms of the GNU General Public License as published by
*  the Free Software Foundation; either version 2, or (at your option)
*  any later version.
*
*  This Program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
*  GNU General Public License for more details.
*
*  You should have received a copy of the GNU General Public License
*  along with XBMC; see the file COPYING.  If not, see
*  <http://www.gnu.org/licenses/>.
*
*/

#include "system.h"
#include <list>
#include "WinEventsIOS.h"
#include "input/XBMC_vkeys.h"
#include "Application.h"
#include "windowing/WindowingFactory.h"
#include "threads/CriticalSection.h"
#include "guilib/GUIWindowManager.h"
#include "utils/log.h"

static CCriticalSection g_inputCond;

PHANDLE_EVENT_FUNC CWinEventsBase::m_pEventFunc = NULL;

static std::list<XBMC_Event> events;

void CWinEventsIOS::DeInit()
{
}

void CWinEventsIOS::Init()
{
}

void CWinEventsIOS::MessagePush(XBMC_Event *newEvent)
{
  CSingleLock lock(g_inputCond);

  events.push_back(*newEvent);
}

bool CWinEventsIOS::MessagePump()
{
  bool ret = false;
  
  // Do not always loop, only pump the initial queued count events. else if ui keep pushing
  // events the loop won't finish then it will block xbmc main message loop.
  for (int pumpEventCount = GetQueueSize(); pumpEventCount > 0; --pumpEventCount)
  {
    // Pop up only one event per time since in App::OnEvent it may init modal dialog which init
    // deeper message loop and call the deeper MessagePump from there.
    XBMC_Event pumpEvent;
    {
      CSingleLock lock(g_inputCond);
      if (events.size() == 0)
        return ret;
      pumpEvent = events.front();
      events.pop_front();
    }  
    
    if (pumpEvent.type == XBMC_USEREVENT)
    {
      // On ATV2, we push in events as a XBMC_USEREVENT,
      // the jbutton.which will be the keyID to translate using joystick.AppleRemote.xml
      // jbutton.holdTime is the time the button is hold in ms (for repeated keypresses)
      std::string joystickName = "AppleRemote";
      bool isAxis = false;
      float fAmount = 1.0;
      unsigned char wKeyID = pumpEvent.jbutton.which;
      unsigned int holdTime = pumpEvent.jbutton.holdTime;

      CLog::Log(LOGDEBUG,"CWinEventsIOS: Button press keyID = %i", wKeyID);
      ret |= g_application.ProcessJoystickEvent(joystickName, wKeyID, isAxis, fAmount, holdTime);
    }
    else
      ret |= g_application.OnEvent(pumpEvent);

//on ios touch devices - unfocus controls on finger lift
#if !defined(TARGET_DARWIN_IOS_ATV2)
    if (pumpEvent.type == XBMC_MOUSEBUTTONUP)
    {
      g_windowManager.SendMessage(GUI_MSG_UNFOCUS_ALL, 0, 0, 0, 0);
    }
#endif
  }

  return ret;
}

int CWinEventsIOS::GetQueueSize()
{
  CSingleLock lock(g_inputCond);
  return events.size();
}
