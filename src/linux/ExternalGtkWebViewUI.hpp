/*
 * Hip-Hop / High Performance Hybrid Audio Plugins
 * Copyright (C) 2021 Luciano Iam <oss@lucianoiam.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#ifndef EXTERNALGTKWEBVIEWUI_HPP
#define EXTERNALGTKWEBVIEWUI_HPP

#include <cstdint>
#include <sys/types.h>

#include "extra/Thread.hpp"

#include "../WebUI.hpp"
#include "ipc.h"
#include "helper.h"

START_NAMESPACE_DISTRHO

class ExternalGtkWebViewUI : public WebUI
{
friend class IpcReadThread;

public:
    ExternalGtkWebViewUI();
    ~ExternalGtkWebViewUI();
    
    void   parameterChanged(uint32_t index, float value) override;

    void   reparent(uintptr_t windowId) override;
    String getSharedLibraryPath() override;
    String getPluginBundlePath() override;

private:
    ipc_t* ipc() const { return fIpc; }
    int    ipcWrite(opcode_t opcode, const void *payload, int payloadSize); 
    void   ipcReadCallback(const tlv_t& message);

    int     fPipeFd[2][2];
    pid_t   fPid;
    ipc_t*  fIpc;
    Thread* fIpcThread;

};

class IpcReadThread : public Thread
{
public:
    IpcReadThread(ExternalGtkWebViewUI& view);
    
    void run() override;

private:
    ExternalGtkWebViewUI& fView;

};

END_NAMESPACE_DISTRHO

#endif  // EXTERNALGTKWEBVIEWUI_HPP
