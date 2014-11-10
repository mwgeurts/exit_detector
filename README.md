## TomoTherapy Exit Detector Analysis

by Mark Geurts <mark.w.geurts@gmail.com>
<br>Copyright &copy; 2014, University of Wisconsin Board of Regents

The TomoTherapy&reg; Exit Detector Analysis project is a GUI based standalone application written in MATLAB that parses [TomoTherapy](http://www.accuray.com) patient archives and DICOM RT Exit Dose files and uses the MVCT response collected during a Static Couch DQA procedure to estimate the fluence delivered through each MLC leaf during treatment delivery.  By comparing the measured fluence to an expected fluence (calculated during optimization of the treatment plan), the treatment delivery performance of the TomoTherapy Treatment System can be observed.

In addition, this project includes a module `CalcDose()`, which uses the Standalone GPU TomoTherapy Dose Calculator to calculate the effect of fluence errors (measured above) on the optimized dose distribution and dose volume histogram for the patient. The module `CalcGamma()` is also included, and performs a 3D [gamma analysis](http://www.ncbi.nlm.nih.gov/pubmed/9608475) between the reference and DQA dose distributions using global 3%/3mm (or otherwise specified) criteria.

The user interface provides graphic and quantitative analysis of the comparison of the measured and expected fluence delivered, as well as a graphical display of the planned dose, recomputed dose, and 3D gamma.  Finally a graphical and tabular comparison of structure dose volume histograms is included to investigate the clinical impact of the measured differences.  A report function is included to generate a PDF report of the results for documentation in the patient's medical record.

TomoTherapy is a registered trademark of Accuray Incorporated.

## Contents

* [Installation and Use](README.md#installation-and-use)
* [Compatibility and Requirements](README.md#compatibility-and-requirements)
* [Troubleshooting](README.md#troubleshooting)
* [Methods](README.md#methods)
  * [Exit Detector Fluence Computation Methods](README.md#exit-detector-fluence-computation-methods)
  * [Dose Calculation Methods](README.md#dose-calculation-methods)
  * [Gamma Computation Methods](README.md#gamma-computation-methods)
* [Third Party Statements](README.md#third-party-statements)

## Installation and Use

To install the TomoTherapy Exit Detector Analysis application, copy all MATLAB files (.m and .fig) into a directory on your local workstation.  This application requires MATLAB version R2013a or later and the Image Processing Toolbox version 8.2 or later.  

To enable dose recalculation based on the measured leaf open times, The TomoTherapy Exit Detector Analysis application must be configured to communicate with a dose calculation server.  Open ExitDetector.m and find the following lines in the function `ExitDetector_OpeningFcn()` (note each line is separated by several lines of comments and `Event()` calls in the actual file):

```
addpath('../ssh2_v2_m1_r6/');
handles.ssh2 = ssh2_config('tomo-research','tomo','hi-art');
```

This application uses the [SSH/SFTP/SCP for Matlab (v2)] (http://www.mathworks.com/matlabcentral/fileexchange/35409-sshsftpscp-for-matlab-v2) interface based on the Ganymed-SSH2 javalib for communication with the dose calculation server.  If performing dose calculation, this interface must be downloaded and the ExitDetector.m statement `addpath('../ssh2_v2_m1_r6/')` modified to reflect its location.  If this interface is not available, use of the TomoTherapy Exit Detector Analysis application is still available for sinogram comparison, but all dose and Gamma computation and evaluation functionality will be automatically disabled.

Next, edit `ssh2_config()` with the the IP/DNS address of the dose computation server (tomo-research, for example), a user account on the server (tomo), and password (hi-art).  This user account must have SSH access rights, rights to execute `gpusadose`, and finally read/write acces to the temp directory.  See Accuray Incorporated to see if your research workstation includes this feature.

Finally, for dose calculation copy the following beam model files in a folder named `GPU` in the MATLAB directory.  These files will be copied to the computation server along with the plan files at the time of program execution.  To change this directory, edit 

* dcom.header
* lft.img
* penumbra.img
* kernel.img
* fat.img

For Gamma calculation, if the Parallel Computing Toolbox is enabled, `CalcGamma()` will attempt to compute the three-dimensional computation using a compatible CUDA device.  To test whether the local system has a GPU compatible device installed, run `gpuDevice(1)` in MATLAB.  All GPU calls in this application are executed in a try-catch statement, and automatically revert to an equivalent (albeit longer) CPU based computation if not available or if the available memory is insufficient.

## Compatibility and Requirements

The TomoTherapy Exit Dose Analysis application uses three inputs: MVCT detector data from a TQA Daily QA module delivery, MVCT data from a patient-specific Static Couch DQA delivery, and a patient archive (following plan approval) of the patient for which the Static Couch DQA was run.  

The MVCT data can be loaded using two different modes.  In DICOM mode, this application reads Transit Dose DICOM RT objects exported from the TomoTherapy version 5.0 treatment system.  In Archive mode, the MVCT data for the TQA Daily QA module can be loaded from a patient archive of the TQA Daily QA patient, while the Static Couch DQA is loaded from the selected XML.  In Archive mode, both TomoTherapy version 5.0 and 4.2 archives have been validated with this application.

For MATLAB, this application has been validated in versions R2013a and R2014a, Image Processing Toolbox 8.2 and 9.0, and Parallel Computing Toolbox version 6.4 on Macintosh OSX 10.8 (Mountain Lion) and 10.9 (Mavericks).

## Troubleshooting

This application records key input parameters and results to a log.txt file using the `Event()` function. The log is the most important route to troubleshooting errors encounetered by this software.  The author can also be contacted using the information above.  Refer to the license file for a full description of the limitations on liability when using or this software or its components.

## Methods

The following sections describe the high level theory behind the computation of the measured fluence using the exit detector sinogram.  For full details, see the [wiki pages](https://github.com/mwgeurts/exit_detector/wiki).

### Exit Detector Fluence Computation Methods

The TomoTherapy Exit Detector Analysis application is based on the hypothesis that the MVCT detector response *R(leaf)* for a given leaf with an expected fluence *F(leaf)* can be modeled by the following convolution: 

*R = S (F + E) &otimes; LSF(leaf) + Bkgd*

where *E(leaf)* is the delivery error, *Bkdg* is the background signal on the MVCT detector (due to leakage radiation and dark current), *S(leaf)* is the sensitivity of the channel (*(R-Bkgd)/F* in an open field where *F* is known with minimal error), and *LSF(leaf)* is a Line Spread Function representing the scatter from *leaf* onto the MVCT detctor channels.  In practice, the center of each MLC leaf is mapped to an MVCT detector channel, and *LSF* is measured based on the relative signal from the mapped channel to neighboring leaf channels.  

For mathematical simplicity, *LSF* is further assumed to be identical for all leaves, reducing the convolution to simple multiplication of Discrete Fourier Transforms according to the Convolution Theorem, as shown below:

*FT(R - Bkgd) = FT(S(F + E)) &bull; FT(LSF)*

The above equation can be solved for *E* as follows, where *IFT* denotes the inverse Discrete Fourier Transform:

*E = IFT(FT(R - Bkgd) / FT(LSF)) / S - F*

Upon loading the TQA Daily QA MVCT detector response data, the application parses the parameters *Bkgd*, *LSF*, and *S* based on a known delivery plan and expected MVCT detector response (assuming the system is well twinned to the Gold Standard).

Next, the expected fluence *F* is obtained by parsing the patient archive and extracting the percent leaf open times, relative to the projection time, for the Machine Agnostic delivery plan at each projection.  The measured Static Couch DQA exit detector response *R* is then read through DICOM or the patient archive (see above notes regarding compatibility).  Static Couch DQA plans are used as they allow the couch to remain out of the bore during treatment delivery, yielding a measured MVCT detector response that minimizes additional scatter, allowing a simple *LSF* to be accurately applied. 

### Dose Calculation Methods

Following sinogram analysis, the delivery error *E* for each leaf and projection has been estimated.  During this next step, this error is applied to the Fluence delivery plan.  Dose is calculated twice; first with the original Fluence delivery plan, and then with the error applied.  Constraints are set to the modified delivery plan, such that leaf open times are not allowed to exceed 100% (full open) or below zero.  

Dose is computed using the TomoTherapy GPU Standalone Dose Calculator version 5.0 application `gpusadose`, using inputs derived from the Dynamic Jaw TP+1 beam model.

### Gamma Computation Methods

Following dose re-calculation, a Gamma analysis is performed based on the formalism presented by D. A. Low et. al., [A technique for the quantitative evaluation of dose distributions.](http://www.ncbi.nlm.nih.gov/pubmed/9608475), Med Phys. 1998 May; 25(5): 656-61.  In this formalism, the Gamma quality index *&gamma;* is defined as follows for each point in measured dose/response volume *Rm* given the reference dose/response volume *Rc*:

*&gamma; = min{&Gamma;(Rm,Rc}&forall;{Rc}*

where:

*&Gamma; = &radic; (r^2(Rm,Rc)/&Delta;dM^2 + &delta;^2(Rm,Rc)/&Delta;DM^2)*,

*r(Rm,Rc) = | Rc - Rm |*,

*&delta;(Rm,Rc) = Dc(Rc) - Dm(Rm)*,

*Dc(Rc)* and *Dm(Rm)* represent the reference and measured doses at each *Rc* and *Rm*, respectively, and

*/&Delta;dM* and *&Delta;DM* represent the absolute and Distance To Agreement Gamma criterion (by default 3%/3mm), respectively.  

The absolute criterion is typically given in percent and can refer to a percent of the maximum dose (commonly called the global method) or a percentage of the voxel *Rm* being evaluated (commonly called the local method).  The application is capable of computing gamma using either approach, and can be set in the ExitDetector.m by editing the line `handles.local_gamma = 0;` from 0 to 1.  By default, the global method (0) is applied.

The computation applied in the TomoTherapy Exit Detector Analysis tool is a 3D algorithm, in that the distance to agreement criterion is evaluated in all three dimensions when determining *min{&Gamma;(Rm,Rc}&forall;{Rc}*. To accomplish this, the modified dose volume is shifted along all three dimensions relative to the reference dose using linear 3D interpolation.  For each shift, *&Gamma;(Rm,Rc}* is computed, and the minimum value *&gamma;* is determined.  To improve computation efficiency, the computation space *&forall;{Rc}* is limited to twice the distance to agreement parameter.  Thus, the maximum "real" Gamma index returned by the application is 2.

## Third Party Statements

SSH/SFTP/SCP for Matlab (v2)
<br>Copyright &copy; 2013, David S. Freedman
<br>All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in
  the documentation and/or other materials provided with the distribution

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

