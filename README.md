# OP-GLX
Online Processing/Plotting of neural data acquired with SpikeGLX.

## Overview
Detailed description of Toolbox can be found in the accompanying paper.

## Prerequisites
Applications and scripts were developed and tested on Windows 11

### MATLAB
Requirements:
- MATLAB >= R2024b
- Toolboxes:
  - Curve Fitting Toolbox
  - DSP System Toolbox
  - Parallel Computing Toolbox
  - Signal Processing Toolbox
  - Statistics and Machine Learning Toolbox

### SpikeGLX
Tested on Release_v20241215-phase30. As of February 26, 2025 this version was removed. Download and installation of the latest SpikeGLX version can be found [here](https://billkarsh.github.io/SpikeGLX/).

### SpikeGLX-MATLAB-SDK
Source code and setup instruction can be found [here](https://github.com/billkarsh/SpikeGLX-MATLAB-SDK).

Important: 
- The current OP-GLX release is packaged with a [specific version](https://github.com/billkarsh/SpikeGLX-MATLAB-SDK/tree/26ae92d05bae6c7efdecca81bb3e255d2ef44dfe) of the SpikeGLX-MATLAB-SDK.
- 
## Installation/Setup
### For the current toolbox:
1. Download `OP-GLX_#_#_#.mltbx` located in the `release/` folder.
2. With MATLAB open, run the `.mltbx` file.
3. Once the process finishes, the toolbox is installed.

To verify installation and initialize the toolbox, in the MATLAB command window run:
```command
>> opglx.initialize();
```
If successful, the following will be displayed:
```command
[OP-GLX YYYY-MM-DD HH:MM:SS] Initializing toolbox...
[OP-GLX YYYY-MM-DD HH:MM:SS] Default file directory set: 
[OP-GLX YYYY-MM-DD HH:MM:SS] C:\Users\<UserName>\AppData\Roaming\MathWorks\MATLAB\<MATLAB-Release>\OP-GLX
[OP-GLX YYYY-MM-DD HH:MM:SS] Toolbox initialized.
```

### For developing:
Development of the toolbox utilizes MATLAB projects.
1. Clone the repository.
2. With MATLAB open, in the `HOME` tab, click the `Open` option.
3. Navigate to the location of the clone repository and open `OP-GLX.prj`. 
4. Source control can be done within MATLAB in the `PROJECT` tab or using Git.
### 