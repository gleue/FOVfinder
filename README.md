FOVfinder
=========

A tool to experimentally determine the field of view for Augmented Reality overlays by
interactively matching reference shapes.

<p align="center">
<img src="https://raw.github.com/gleue/FOVfinder/master/Screenshots/Screenshot-1.png" alt="FOVfinder Main View" title="FOVfinder Main View">
<img src="https://raw.github.com/gleue/FOVfinder/master/Screenshots/Screenshot-2.png" alt="FOVfinder Settings View" title="FOVfinder Settings View">
</p>

Usage
=====

Build and run `FOVfinder.xcodeproj` on an iDevice. The app will run on the simulator, too,
but will give you no camera image.

On the main view use a pinch gesture to adjust the field of view angle so that the white
overlay frames match the reference objects in the camera preview. Currently the angle may
be changed in 1 degree steps, only. The field of view may be determined for landscape and
portrait orientation.

A tap on the camera preview toggles the navigation and tool bars in the main view.

Use the Settings view to adjust video gravity of the <code>AVCaptureVideoPreviewLayer</code>
as well as size and offsets of the overlay frames. All measures are given in centimeters, but
the underlying projection geometry is basically unit-less.

Requirements
============

* ARC
* iOS 7
* Xcode 5
* iDevice, since Simulator does not have a camera

License
=======

FOVfinder is available under the MIT License (MIT)

Copyright (c) 2014 Tim Gleue (http://gleue-interactive.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
