/*
 * dpf-webui
 * Copyright (C) 2021 Luciano Iam <lucianoiam@protonmail.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any purpose with
 * or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD
 * TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN
 * NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
 * DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <deque>

#include "WebUI.hpp"
#include "Window.hpp"

#include "base/Platform.hpp"
#include "base/macro.h"

USE_NAMESPACE_DISTRHO

WebUI::WebUI()
    : fWebView(*this)
    , fParentWindowId(0)
{
    float scaleFactor = platform::getSystemDisplayScaleFactor();
    setSize(scaleFactor * DISTRHO_UI_INITIAL_WIDTH, scaleFactor * DISTRHO_UI_INITIAL_HEIGHT);
#if defined(DISTRHO_UI_BACKGROUND_COLOR) && defined(DGL_OPENGL)
    glClearColor(DISTRHO_UNPACK_RGBA_NORM(DISTRHO_UI_BACKGROUND_COLOR, GLfloat));
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
#endif
    String dpfjs = String(
#include "base/dpf.js"
    );
    fWebView.injectScript(dpfjs);
    fWebView.resize(getSize());
    fWebView.navigate("file://" + platform::getResourcePath() + "/index.html");
}

void WebUI::onDisplay()
{
    const Window& window = getParentWindow();
#if defined(DISTRHO_UI_BACKGROUND_COLOR) && defined(DGL_CAIRO)
    cairo_t* cr = window.getGraphicsContext().cairo;
    cairo_set_source_rgba(cr, DISTRHO_UNPACK_RGBA_NORM(DISTRHO_UI_BACKGROUND_COLOR, double));
    cairo_paint(cr);
#endif
    // onDisplay() can be called multiple times during lifetime of instance
    uintptr_t newParentWindowId = window.getWindowId();
    if (fParentWindowId != newParentWindowId) {
        fParentWindowId = newParentWindowId;
        fWebView.reparent(fParentWindowId);
    }
}

void WebUI::onResize(const ResizeEvent& ev)
{
    fWebView.resize(ev.size);
}

void WebUI::parameterChanged(uint32_t index, float value)
{
    webViewPostMessage({"DPF", "parameterChanged", index, value});
}

void WebUI::webViewLoadFinished()
{
    // TODO - send state?

    // TEST CALL
    parameterChanged(123, 4.5);
}

bool WebUI::webViewScriptMessageReceived(const ScriptValueVector& args)
{
    if ((args.size() < 4) || (args[0].getString() != "DPF")) {
        return false;
    }
    String method = args[1].getString();
    if (method == "editParameter") {
        uint32_t index = static_cast<uint32_t>(args[2].getDouble());
        bool started = static_cast<bool>(args[3].getBool());
        editParameter(index, started);
        ::printf("Native received editParameter(%d,%s)\n", index, started ? "true" : "false");
    } else if (method == "setParameterValue") {
        // uint32_t index, float value
#if DISTRHO_PLUGIN_WANT_STATE
    } else if (method == "setState") {
        // const char* key, const char* value
#endif
    } else {
        DISTRHO_LOG_STDERR_COLOR("Invalid call to native DPF method");
    }
    return true;
}
