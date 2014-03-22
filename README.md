## TomoTherapy Exit Detector Analysis

by Mark Geurts <mark.w.geurts@gmail.com>
<br>Copyright &copy; 2014, University of Wisconsin Board of Regents

The TomoTherapy(R) Exit Detector Analysis project is a GUI based standalone application written in MATLAB that parses [TomoTherapy](http://www.accuray.com) patient archives and DICOM RT Exit Dose files and uses the MVCT response collected during a Static Couch DQA procedure to estimate the fluence delivered through each MLC leaf during treatment delivery.  By comparing the measured fluence to an expected fluence (calculated during optimization of the treatment plan), the treatment delivery performance of the TomoTherapy Treatment System can be observed.  The user interface provides graphic and quantitative analysis of the comparison of the measured and expected fluence delivered.

In addition, this project includes a module `CalcDose(handles)`, which uses the Standalone GPU TomoTherapy Dose Calculator to calculate the effect of fluence errors (measured above) on the optimized dose distribution for the patient. The `DoseViewer(varargin)` module is a child user interface developed to allow visualization of the reference, adjusted (or DQA), and dose differences on the patient CT.  The module `CalcGamma(handles)` is also included, and performs a 3D [gamma analysis](http://www.ncbi.nlm.nih.gov/pubmed/9608475) between the reference and DQA dose distributions.

TomoTherapy is a registered trademark of Accuray Incorporated.

### Installation and Use

To install the TomoTherapy Exit Detector Analysis application, copy all MATLAB files (.m and .fig) into a directory on your local workstation.  This application requires MATLAB version R2013a or later and the Image Processing Toolbox version 8.2 or later.  

To enable dose recalculation based on the measured leaf open times, The TomoTherapy Exit Detector Analysis application must be configured to communicate with a dose calculation server.  Open MainPanel.m and find the following lines in the function `MainPanel_OpeningFcn()` (note each line is separated by several lines of comments in the actual file):

```
addpath('./ssh2_v2_m1_r5/');
handles.ssh2_conn = ssh2_config('tomo-research','tomo','hi-art');
handles.pdut_path = 'GPU/';
```

This application uses the (SSH/SFTP/SCP for Matlab (v2)) [http://www.mathworks.com/matlabcentral/fileexchange/35409-sshsftpscp-for-matlab-v2] interface based on the Ganymed-SSH2 javalib for communication with the dose calculation server.  If performing dose calculation, this interface must be downloaded and the MainPanel.m statement `addpath('./ssh2_v2_m1_r5/')` modified to reflect its location.  If this interface is not available, use of the TomoTherapy Exit Detector Analysis application is still available for sinogram comparison, but all dose and Gamma computation and evaluation functionality will be automatically disabled.

Next, edit `ssh2_config()` with the the IP/DNS address of the dose computation server (tomo-research, for example), a user account on the server (tomo), and password (hi-art).  This user account must have read/write access to the SSH home directory.  In addition, this system must run GNU/Linux 3.2.0-58-generic x64 and be configured with CUDA 5.0 or later using a compatible graphics card with at least 448 cores and 1280 MB of memory.  To test whether all dependencies are available, copy gpusadose to the workstation and use the lld command.

Finally, for dose calculation `handles.pdut_path` must contain the location on the local server of the gpusadose executable and beam model files:

* dcom.header
* lft.img
* penumbra.img
* kernel.img
* fat.img

For Gamma calculation, if the Parallel Computing Toolbox is enabled, `CalcGamma(handles)` will attempt to start three parallel threads on the local workstation to increase the computing efficiency.  Depending on memory and computing capacity available on the workstation, this number can be edited by changing `parpool(3)` in CalcGamma.m to a different number.  To turn off parallel computation completely, set `handles.parallelize = 0;` in `MainPanel_OpeningFcn()`.

### Version Compatibility

The TomoTherapy Exit Dose Analysis application uses three inputs: MVCT detector data from a TQA Daily QA module delivery, MVCT data from a patient-specific Static Couch DQA delivery, and a patient archive (following plan approval) of the patient for which the Static Couch DQA was run.  

The MVCT data can be loaded using two different modes.  In DICOM mode, this application reads Transit Dose DICOM RT objects exported from the TomoTherapy version 5.0 treatment system.  In Archive mode, the MVCT data for the TQA Daily QA module can be loaded from a patient archive of the TQA Daily QA patient, while the Static Couch DQA is loaded from the selected XML.  In Archive mode, both TomoTherapy version 5.0 and 4.2 archives have been validated with this application.

For MATLAB, this application has been validated in versions R2013a and R2014a, Image Processing Toolbox 8.2 and 9.0, and Parallel Computing Toolbox version 6.4 on Macintosh OSX 10.8 (Mountain Lion) and 10.9 (Mavericks).

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

Dose is computed using the TomoTherapy GPU Standalone Dose Calculator version 5.0 application `gpusadose`, using inputs derived from the Dynamic Jaw TP+1 beam model.  Because the dose difference is determined from the reference and modified dose arrays, both of which are computed using the same model, it is not critically important that the treatment system being evaluated exactly match the beam model used for analysis.

### Gamma Computation Methods

Finally, following dose re-calculation, a Gamma analysis is performed based on the formalism presented by D. A. Low et. al., [A technique for the quantitative evaluation of dose distributions.](http://www.ncbi.nlm.nih.gov/pubmed/9608475), Med Phys. 1998 May; 25(5): 656-61.  In this formalism, the Gamma quality index *&gamma;* is defined as follows for each point in measured dose/response volume *Rm* given the reference dose/response volume *Rc*:

*&gamma; = min{&Gamma;(Rm,Rc}&forall;{Rc}*

where:

*&Gamma; = &radic; (r^2(Rm,Rc)/&Delta;dM^2 + &delta;^2(Rm,Rc)/&Delta;DM^2)*,

*r(Rm,Rc) = | Rc - Rm |*,

*&delta;(Rm,Rc) = Dc(Rc) - Dm(Rm)*,

*Dc(Rc)* and *Dm(Rm)* represent the reference and measured doses at each *Rc* and *Rm*, respectively, and

*/&Delta;dM* and *&Delta;DM* represent the absolute and Distance To Agreement Gamma criterion (by default 3%/3mm), respectively.  

The absolute criterion is typically given in percent and can refer to a percent of the maximum dose (commonly called the global method) or a percentage of the voxel *Rm* being evaluated (commonly called the local method).  The application is capable of computing gamma using either approach, and can be set in the MainPanel.m by editing the line `handles.local_gamma = 0;` from 0 to 1.  By default, the global method (0) is applied.

The computation applied in the TomoTherapy Exit Detector Analysis tool is a 3D algorithm, in that the distance to agreement criterion is evaluated in all three dimensions when determining *min{&Gamma;(Rm,Rc}&forall;{Rc}*. To accomplish this, the modified dose volume is shifted along all three dimensions relative to the reference dose using linear 3D interpolation.  For each shift, *&Gamma;(Rm,Rc}* is computed, and the minimum value *&gamma;* is determined.  To improve computation efficiency, the computation space *&forall;{Rc}* is limited to twice the distance to agreement parameter.  Thus, the maximum "real" Gamma index returned by the application is 2.

### Third Party Statements

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

