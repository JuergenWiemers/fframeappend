# fframeappend

Appends data frames to the active data frame in Stata

## Installation

To install the Stata package, clone or download this repo, and then
copy `fframeappend.ado` and `fframeappend.sthlp` to your personal
ado folder. You can find this folder using the `sysdir` command.

## Remarks

**fframeappend** is another intermediate solution on the way to a (hopefully) future built-in **frame append** command in Stata.
**fframeappend** is heavily inspired by the existing SSC packages **frameappend** written by Jeremy Freese and revised with help from Daniel Fernandez, and **xframeappend** written by Roger Newsom.
The distinguishing feature of **fframeappend** (apart from being able to append subsets of variables and observations) is its speed: For relatively large using data frames (>100.000 observation, >1.000 variables) it is about 20 times faster than existing solutions.


## Author

* Jürgen Wiemers -- Contact me at juergen.wiemers [at] iab [dot] de

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
