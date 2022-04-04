{smcl}
{* *! version 1.0.2  4apr2022}{...}
{title:Title}

{phang}
{bf:fframeappend} {hline 2} Append data frame to currently active data frame


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:fframeappend}
    [{it:{help varlist}}]
    {ifin}
    {cmd:, using(framename)}
    [{cmd:force} {cmd:{help preserve}}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt force}} append string to numeric or numeric to string without error{p_end}
{synopt:{opt preserve}} master frame will be restored if the program fails or if the user presses {helpb break:Break}{p_end}

{marker description}{...}
{title:Description}

{pstd}
{cmd:fframeappend} appends the variables {it:{help varlist}} in the "using frame" to the currently active frame. 
If no {it:{help varlist}} is provided, all variables in the using frame will be appended to the currently active frame. 
The new observations will be at the bottom of the currently active frame. 
Variables in the currently active frame are automatically promoted following the promotion rules of {cmd:{help replace}}.
The ordering of variables in the currently active frames is preserved. 
With option {cmd:force}, the appended values for incompatible variables (numeric <-> string) are filled with missing values or empty strings, 
depending on the type of the incompatible variable in the currently active frame.

{title:Remarks and Acknowledgements}

{pstd}
{cmd:fframeappend} is another intermediate solution on the way to a (hopefully) future {cmd:frame append} command.
{cmd:fframeappend} is heavily inspired by the existing {help ssc:SSC} packages {helpb frameappend} written by Jeremy Freese and revised with help from Daniel Fernandez, and {helpb xframeappend} written by Roger Newsom.
The distinguishing feature of {cmd:fframeappend} (apart from being able to append subsets of variables and observations) is its speed: 
For relatively large using data frames (>100.000 observation, >1.000 variables) it is about 20 times faster than existing solutions.

{marker author}{...}
{title:Author}

{pstd}
Jürgen Wiemers, IAB Nürnberg, juergen.wiemers@iab.de

