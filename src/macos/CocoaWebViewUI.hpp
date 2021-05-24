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

#ifndef COCOAWEBVIEWUI_HPP
#define COCOAWEBVIEWUI_HPP

#include "../WebUI.hpp"

#import <WebKit/WebKit.h>

START_NAMESPACE_DISTRHO

class CocoaWebViewUI : public WebUI
{
public:
    CocoaWebViewUI();
    ~CocoaWebViewUI();
    
    void   parameterChanged(uint32_t index, float value) override;

    void   reparent(uintptr_t windowId) override;
    String getSharedLibraryPath() override;

private:
    WKWebView *fView;

};

END_NAMESPACE_DISTRHO

#endif  // COCOAWEBVIEWUI_HPP
