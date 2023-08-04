# fframeappend

Appends data frames to the active data frame in Stata

Latest SSC version: v1.1.0

## Installation

To install the latest stable version (v1.1.0) of this package, run the following line from the Stata prompt:

```stata
net install fframeappend, from(https://raw.githubusercontent.com/JuergenWiemers/fframeappend/master/src) replace
```

or install the package through SSC.

## Recent Updates

* **version v1.1.1 4aug2023**:
    - Bugfixes:
      - After 1.1.0, abbreviating variables in varlist didn't work anymore. This has been fixed.
    - Improvements:
      - Previously, if 'varlist' was specified and a given variable was missing in the n-th using frame (but not in using frames 1 to (n-1)) the first n-1 frames were appended and then an error message about the missing variable was issued. Then, if option 'preserve' was also chosen, the currently active using frame was restored. Now the command fails early: The existence of all variables in 'varlist' in all using frames is checked before appending any using frames.


* **version v1.1.0 31jul2023**:
    - Option `using` now accepts multiple frame names. All `using` frames are appended in the specified order. Wildcards are allowed, e.g., `using(fr*)`.
    - Option `generate(newvarname)` generates a variable that indicates the original frame of the observations.
    - Option `drop` drops appended using frames. Useful for conserving memory.
    - Bugfixes:
      - Variables of type `strL` in either the master or any using frame previously resulted in a runtime error. This has been fixed.
      - Previously, after appending the using frames, Stata considered the data in the master frame to be sorted according to the sort variables in the master frame (if the master frame was sorted before running `fframeappend`) even if - because of the appended using frames - it wasn't. This could cause unexpected results, e.g., in a `merge` command following `fframeappend` because `merge` (falsely) considered the dataset to be correctly sorted. This has been fixed. Thanks to Stefan Mangelsdorf for notifying me about this issue.


## Remarks

**fframeappend** is another intermediate solution on the way to a (hopefully) future built-in **frame append** command in Stata.
**fframeappend** is heavily inspired by the existing SSC packages **frameappend** written by Jeremy Freese and revised with help from Daniel Fernandez, and **xframeappend** written by Roger Newsom.
The distinguishing feature of **fframeappend** (apart from being able to append subsets of variables and observations) is its speed: For relatively large using data frames (>100.000 observation, >1.000 variables) it is about 20 times faster than existing solutions.


## Author

* Jürgen Wiemers -- Contact me at juergen.wiemers [at] iab [dot] de

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
