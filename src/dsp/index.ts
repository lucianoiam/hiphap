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

import DISTRHO from './distrho-plugin'
import PluginImpl from './plugin'

// The interface defined in this file is private to the framework and optimized
// for Wasmer integration. Do not use it for creating plugins, use the public
// interface provided by distrho-plugin.ts instead.

const pluginInstance = new PluginImpl

// These are external functions implemented by the native container. They are
// declared here instead of the caller module (distrho-plugin.ts) to keep all
// interfaces to the native container in a single place (index.ts) and also to
// make sure all declared functions appear listed in the module imports table.

declare function _get_sample_rate(): f32

export { _get_sample_rate }

// Keep _get_label(), _get_maker() and _get_license() as function exports. They
// could be replaced with globals initialized to these function return values
// for a simpler implementation, but maybe in the future index.ts auto injected
// into the Wasm VM (just like done with ui.js for the web view) and plugin
// implementations moved to "linked modules". Under such scheme the guarantee
// that global pluginInstance is already init'd at this point no longer holds.

export function _get_label(): ArrayBuffer {
    return _c_string(pluginInstance.getLabel())
}

export function _get_maker(): ArrayBuffer {
    return _c_string(pluginInstance.getMaker())
}

export function _get_license(): ArrayBuffer {
    return _c_string(pluginInstance.getLicense())
}

export function _get_version(): u32 {
    return pluginInstance.getVersion()
}

export function _get_unique_id(): i64 {
    return pluginInstance.getUniqueId()
}

export function _init_parameter(index: u32): void {
    const parameter = new DISTRHO.Parameter
    pluginInstance.initParameter(index, parameter)
    // See explanation below for the odd value return convention
    _rw_int_1 = parameter.hints
    _ro_string_1 = _c_string(parameter.name)
    _rw_float_1 = parameter.ranges.def
    _rw_float_2 = parameter.ranges.min
    _rw_float_3 = parameter.ranges.max
}

export function _get_parameter_value(index: u32): f32 {
    return pluginInstance.getParameterValue(index)
}

export function _set_parameter_value(index: u32, value: f32): void {
    pluginInstance.setParameterValue(index, value)
}

export function _activate(): void {
    pluginInstance.activate()
}

export function _deactivate(): void {
    pluginInstance.deactivate()
}

let run_count = 0

export function _run(frames: u32): void {
    let inputs: Array<Float32Array> = []

    for (let i = 0; i < _num_inputs; i++) {
        inputs.push(Float32Array.wrap(_input_block, i * frames * 4, frames))
    }

    let outputs: Array<Float32Array> = []

    for (let i = 0; i < _num_outputs; i++) {
        outputs.push(Float32Array.wrap(_output_block, i * frames * 4, frames))
    }

    pluginInstance.run(inputs, outputs)

    // Run AS garbage collector every N calls. Default TLSF + incremental GC
    // https://www.assemblyscript.org/garbage-collection.html#runtime-variants
    // TODO: This is apperently only needed on Windows to avoid segfault after
    //       a certain period of time. Need to investigate root cause.

    if ((run_count++ % 100) == 0) {
        __collect()
    }
}

// Number of inputs or outputs does not change during runtime so it makes sense
// to init both once instead of passing them as arguments on every call to run()

export let _num_inputs: i32
export let _num_outputs: i32

// Using exported globals instead of passing buffer arguments to run() allows
// for a simpler implementation by avoiding Wasm memory alloc on the host side.
// Block size should not exceed 64Kb, or 16384 frames of 32-bit float samples.

const MAX_PROCESS_BLOCK_SIZE = 65536

export let _input_block = new ArrayBuffer(MAX_PROCESS_BLOCK_SIZE)
export let _output_block = new ArrayBuffer(MAX_PROCESS_BLOCK_SIZE)

// TypedArray exports needed by the JS loader

export let _input_block_float32 = Float32Array.wrap(_input_block)
export let _output_block_float32 = Float32Array.wrap(_output_block)

// AssemblyScript does not support multi-values yet. Export a couple of generic
// variables for returning complex data types like initParameter() needs.

export let _rw_int_1: i32
export let _rw_int_2: i32
export let _rw_int_3: i32
export let _rw_int_4: i32
export let _rw_float_1: f32
export let _rw_float_2: f32
export let _rw_float_3: f32
export let _rw_float_4: f32
export let _ro_string_1: ArrayBuffer
export let _ro_string_2: ArrayBuffer
export let _ro_string_3: ArrayBuffer
export let _ro_string_4: ArrayBuffer

// These are useful for passing string arguments from the native context to Wasm

const MAX_STRING = 1024

export let _rw_string_1 = new ArrayBuffer(MAX_STRING)

// Converting AssemblyScript strings to C-style strings here is simpler than
// doing so on the native side. This function needs to be exported because AS
// requires an abort() function to be implemented by the host in non-WASI mode.
// abort() is called with some string args which need to be read by the host.

export function _c_string(s: string): ArrayBuffer {
    return String.UTF8.encode(s, true)
} 
