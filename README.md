## TomoTherapy Exit Detector Analysis

by Mark Geurts <mark.w.geurts@gmail.com>
<br>Copyright &copy; 2017, University of Wisconsin Board of Regents

## Description

The TomoTherapy&reg; Exit Detector Analysis Tool is a GUI based standalone application written in MATLAB&reg; that parses [TomoTherapy](http://www.accuray.com) patient archives and DICOM RT Exit Dose files and uses the MVCT response collected during a Static Couch DQA procedure to estimate the fluence delivered through each MLC leaf during treatment delivery.  By comparing the measured fluence to an expected fluence (calculated during optimization of the treatment plan), the treatment delivery performance of the TomoTherapy Treatment System can be observed.

In addition, this project includes the submodule `CalcDose()`, which uses the Standalone GPU TomoTherapy Dose Calculator to calculate the effect of fluence errors (measured above) on the optimized dose distribution and dose volume histogram for the patient. The submodule `CalcGamma()` is also included, and performs a 3D gamma analysis between the reference and DQA dose distributions using global 3%/3mm (or otherwise specified) criteria.

The user interface provides graphic and quantitative analysis of the comparison of the measured and expected fluence delivered, as well as a graphical display of the planned dose, recomputed dose, and 3D gamma.  Finally a graphical and tabular comparison of structure dose volume histograms is included to investigate the clinical impact of the measured differences.  A report function is included to generate a PDF report of the results for documentation in the patient's medical record.

TomoTherapy is a registered trademark of Accuray Incorporated. MATLAB is a registered trademark of MathWorks Inc.

## Installation

To install the TomoTherapy Exit Detector Analysis Tool as a MATLAB App, download and execute the `TomoTherapy Exit Detector Analysis.mlappinstall` file from this directory. If downloading the repository via git, make sure to download all submodules by running  `git clone --recursive https://github.com/mwgeurts/exit_detector`. See the [wiki](../../wiki/Installation-and-Use) for information on configuration parameters and additional documentation.

## Usage

To run this application, run the App or call `ExitDetector` from MATLAB. Once the application interface loads, select browse under inputs to load the daily QA and static couch QA patient archive inputs. Once all data is loaded, the application will automatically process and display the results. If dose calculation is enabled, the user will be prompted whether to calculate dose, and if successful, whether to calculate Gamma.

## License

Released under the GNU GPL v3.0 License.  See the [LICENSE](LICENSE) file for further details.
