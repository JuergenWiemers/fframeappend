{smcl}
{* *! version 1.1.0  31jul2023}{...}
{title:Title}

{phang}
{bf:fframeappend} {hline 2} Append data frames to currently active data frame


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:fframeappend}
    [{it:{help varlist}}]
    {ifin}
    {cmd:, using({it:framelist})}
    [{opt force} {cmd:{help preserve}} {opt drop} {opt g:enerate(newvarname)}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt force}}             append string to numeric or numeric to string without error{p_end}
{synopt:{opt preserve}}          master frame will be restored if the program fails for any using frame or if the user presses {helpb break:Break}{p_end}
{synopt:{opt drop}}              drop using frames after appending. Cannot be chosen in combination with {opt preserve}.{p_end}
{synopt:{opth g:enerate(newvarname)}}  specifies the name of a new variable to be created that indicates the 
original frame for each observation{p_end}

{marker description}{...}
{title:Description}

{pstd}
{cmd:fframeappend} appends the variables {it:{help varlist}} in the frames {it: framelist} to the current frame. 
If no {it:{help varlist}} is provided all variables in frames {it: framelist} will be appended to the current frame. 
If a {it:{help varlist}} is provided all variables must be present in all frames of  {it: framelist}.
If option {cmd:{help in}} is provided the range must be feasible in all frames of  {it: framelist}.
The new observations will be at the bottom of the current frame. 
Variables in the currently active frame are automatically promoted following the promotion rules of {cmd:{help replace}}.
With option {cmd:force}, the appended values for incompatible variables (numeric <-> string) are filled with missing values or empty strings, 
depending on the type of the incompatible variable in the currently active frame. All variable types (see {it:{help data_type}}) are supported.

{title:Remarks and Acknowledgements}

{pstd}
{cmd:fframeappend} is another intermediate solution on the way to a (hopefully) future {cmd:frame append} command.
{cmd:fframeappend} is heavily inspired by the existing {help ssc:SSC} packages {helpb frameappend} written by Jeremy Freese and revised with help from Daniel Fernandez, and {helpb xframeappend} written by Roger Newsom.
The distinguishing feature of {cmd:fframeappend} (apart from being able to append subsets of variables and observations) is its speed: 
For relatively large using data frames (>100.000 observation, >1.000 variables) it is about 20 times faster than existing solutions.

{marker author}{...}
{title:Author}

{pstd}
Jürgen Wiemers, IAB Nürnberg, juergen.wiemers@iab.de, {browse "https://github.com/JuergenWiemers/fframeappend":https://github.com/JuergenWiemers/fframeappend}.

