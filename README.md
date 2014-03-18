## TomoTherapy Exit Detector Analysis

by Mark Geurts <mark.w.geurts@gmail.com>
<br>(c) 2014 University of Wisconsin Board of Regents

The TomoTherapy Exit Detector Analysis project is a GUI based standalone application written in MATLAB that parses [TomoTherapy](http://www.accuray.com) patient archives and DICOM RT Exit Dose files and uses the MVCT response collected during a Static Couch DQA procedure to estimate the fluence delivered through each MLC leaf during treatment delivery.  By comparing the measured fluence to an expected fluence (calculated during optimization of the treatment plan), the treatment delivery performance of the TomoTherapy Treatment System can be observed.  The user interface provides graphic and quantitative analysis of the comparison of the measured and expected fluence delivered.

In addition, this project includes a module `CalcDose()`, which uses the Standalone GPU TomoTherapy Dose Calculator to calculate the effect of fluence errors (measured above) on the optimized dose distribution for the patient. The `DoseViewer(varargin)` module is a child user interface developed to allow visualization of the reference, adjusted (or DQA), and dose differences on the patient CT.  The module `CalcGamma()` is also included, and performs a 3D [gamma analysis](http://www.ncbi.nlm.nih.gov/pubmed/9608475) between the reference and DQA dose distributions.

### Runtime Dependencies

### Version Compatibility

### Installation

### Sinogram Difference Computation Methods

### Dose Calculation Methods

### Gamma Computation Methods
