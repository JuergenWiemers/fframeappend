# fframeappend

Appends data frames to the active data frame in Stata

Latest SSC version: v1.0.3

## Installation

To install the latest stable version (v1.0.3) of this package, run the following line from the Stata prompt:

```stata
net install fframeappend, from(https://raw.githubusercontent.com/JuergenWiemers/fframeappend/master/src)
```

or install the package through SSC.

## Recent Updates

* **version v1.1.0DEV 7jul2023**:
    - `using` now accepts multiple frame names. All `using` frames are appended in the specified order.
    - Option `generate(varname)` specifies the name of a new variable to be created that marks the source of observations. It will have values 0 for observations in the master dataframe (the current frame), and the value k for observations from the kth frame in the framelist.
    
    You can install this development version with
    ```stata
    net install fframeappend, from(https://raw.githubusercontent.com/JuergenWiemers/fframeappend/v1.1.0DEV/src)
    ```


## Remarks

**fframeappend** is another intermediate solution on the way to a (hopefully) future built-in **frame append** command in Stata.
**fframeappend** is heavily inspired by the existing SSC packages **frameappend** written by Jeremy Freese and revised with help from Daniel Fernandez, and **xframeappend** written by Roger Newsom.
The distinguishing feature of **fframeappend** (apart from being able to append subsets of variables and observations) is its speed: For relatively large using data frames (>100.000 observation, >1.000 variables) it is about 20 times faster than existing solutions.


## Author

* Jürgen Wiemers -- Contact me at juergen.wiemers [at] iab [dot] de

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
