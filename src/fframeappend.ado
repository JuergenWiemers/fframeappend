*! fframeappend 1.1.0DEV 18jul2023 Jürgen Wiemers (juergen.wiemers@iab.de)
*! Syntax: fframeappend [varlist] [if] [in], using(framelist) [force preserve Generate(name)]
*!
*! fframeappend ("fast frame append") appends variables from using frames 'framelist'
*! to the active (master) frame.

* This program is free software under the terms of the MIT License

* Version history at bottom

// Wrapper for fframeappend_run
program fframeappend
    version 16

    // Retokenize 0
    local 0: list clean 0    

    // Check if using() is given
    if !strmatch("`0'", "*using(*") {
        display as error "Option 'using()' required"
        exit 198
    }

    // Get current sort information
    qui describe, fullnames varlist
    local sortlist `r(sortlist)'

    // Replace abbreviated frame list with expanded list; rebuild local 0 with expanded list
    local using_frames = regexr( regexr( "`0'", "(.*)using\(", "" ) , "\).*$", "")
    local using_frames: list clean using_frames
    local using_frames: list uniq using_frames
    local expanded_frames
    foreach frame in `using_frames' {
        qui frames dir `frame'
        local expanded_frames `expanded_frames' `r(frames)'
    }
    local expanded_frames: list uniq expanded_frames    
    local 0 = subinstr("`0'", "`using_frames'", "`expanded_frames'", 1)

    // Check if current frame is included in using frames
    qui frame
    local master = r(currentframe)    
    if strmatch("`expanded_frames'", "*`master'") {
        display as error "You are trying to append the current frame to itself"
        exit 110
    }

    // Check `if'/`in' in using frames
    foreach usingf in `expanded_frames' {
        frame `usingf': syntax [anything] [if] [in], using(namelist min=1) [force preserve Generate(name)]
    }

    // Check that generate variable does not exist in master and any using frame
    if "`generate'"!="" {
        cap confirm new variable `generate'
        if _rc == 110 {
            display as error "Variable `generate' already defined in current frame `c(frame)'"
            exit 110
        }
        foreach frame_name in `expanded_frames' {
            frame `frame_name': cap confirm new variable `generate'
            if _rc == 110 {
                display as error "Variable `generate' already defined in frame `frame_name'"
                exit 110                
            }
        }
    }

    // Check whether * or _all are in `anything'
    local flag = 0
    foreach token in * _all {
        local test: list posof "`token'" in anything
        if (`test') local flag = 1
    }
    if (`flag') local anything = ""

    if ("`preserve'" != "") preserve

    if ("`generate'" != "")  {
        generate long `generate' = 0
    }

    // Loop over framelist
    local counter = 0
    foreach usingf in `expanded_frames' {
        local `counter++'
        frame `usingf': cap drop __0* // drop potential local variables in using frames
        fframeappend_run `anything' `if' `in', using(`usingf') `force'
        if ("`generate'" != "") qui replace `generate' = `counter' if `generate' == .
    }

    // Hack to set the master frame to "unsorted"; 
    // Without this, "describe" would (falsely) identify the master frame as sorted after appending.
    if ("`sortlist'" != "") {
        tempvar n
        generate long `n' = _n
        sort `n'
        drop `n'
    }

    if ("`preserve'" != "") restore, not

end

// Main routine
program fframeappend_run    
    // Get name of using frame from args to be able to
    // run 'syntax' on the using frame.
    local using = regexr( regexr( "`0'", "(.*)using\(", "" ) , "\).*$", "")

    frame `using': syntax [anything] [if] [in], using(namelist min=1) [force]

    // Check if variables exist in frame
    if "`anything'" != "" {
        foreach var in `anything' {
            frame `using': capture confirm variable `var'
            if _rc {
                display as error "Variable `var' does not exist in using frame `using'."
                exit 111
            }
        }
    }

    qui frame
    local master = r(currentframe)
    
    frame `using': qui describe `anything', fullnames varlist
    local varlist = r(varlist)

    // Edge case: empty master frame
    mata: st_local("master_has_vars", strofreal(st_nvar()))
    if (!`master_has_vars') {
        frame copy `using' `master', replace
        exit 0
    }

    cwf `master'
    qui describe, fullnames varlist
    local mastervars = r(varlist)

    // Check for variables with incompatible type (string <-> numeric)
    if "`force'" == "" {
        local commonvars: list varlist & mastervars
        mata: incompatible_vars("`commonvars'", "`using'", "`master'")
        if "`incompatible_vars'" != "" {
            display as error "You are trying to append numeric to string variables (or vice versa) for the following variables: "
            display as error "`incompatible_vars'"
            display as error "Use option 'force' if you want to append anyway."
            exit 106
        }
    }

    // Promote variables in master frame if necessary
    local commonvars_excl_inc_vars: list commonvars - incompatible_vars // exclude incompatibe vars
    cwf `master'
    foreach var in `commonvars_excl_inc_vars' {
        mata: st_local("tm", st_vartype("`var'"))
        frame `using': mata: st_local("tu", st_vartype("`var'"))
        
        if ("`tm'" == "`tu'") continue

        cap confirm numeric variable `var', exact // Numeric and string variables need to be treated differently
        if (!_rc) { // numeric
            if      ( ("`tm'" == "byte")  & inlist("`tu'", "int", "long", "float", "double") ) recast `tu' `var'
            else if ( ("`tm'" == "int")   & inlist("`tu'", "long", "float", "double") )        recast `tu' `var'
            else if ( ("`tm'" == "long")  & inlist("`tu'", "float", "double") )                recast double `var'
            else if ( ("`tm'" == "float") & inlist("`tu'", "long", "double") )                 recast double `var'
        }
        else { // string
            if ( subinstr("`tm'", "str", "", 1) < subinstr("`tu'", "str", "", 1) )             recast `tu' `var'
        }
    }

    // If variables in `varlist' do not exist in the master data,
    // generate them (with the type of the using data) and set them
    // to missing / empty string.
    cwf `master'
    local newvars: list varlist - mastervars
    foreach var in `newvars' {
        frame `using': mata: st_local("type", st_vartype("`var'"))
        frame `using': cap confirm numeric variable `var', exact
        local init = cond(!_rc, ".", `""""')
        qui generate `type' `var' = `init'
    }

    cwf `using'
    tempvar touse
    mark `touse' `if' `in'
    
    mata: append("`varlist'", "`using'", "`master'")
    order `mastervars', first
end


mata:
void append(string scalar varlist, string scalar usingframe, string scalar masterframe)
{
    vars = tokens(varlist)
    numtype = J(1, cols(vars), .)
    for (i = 1; i <= cols(vars); i++) {
        numtype[i] = st_isnumvar(vars[i])
    }
    
    numvars = select(vars, numtype)
    strvars = select(vars, !numtype)

    if (rows(numvars) > 0) numvarstr = invtokens(numvars)
    if (rows(strvars) > 0) strvarstr = invtokens(strvars)

    // Create views on using frame
    st_framecurrent(usingframe)

    if (rows(numvars) > 0) st_view(using_numvars = J(0, 0, .), ., numvarstr, st_local("touse"))
    if (rows(strvars) > 0) st_sview(using_strvars = J(0, 0, .), ., strvarstr, st_local("touse"))

    usingnobs = rows(numvars) > 0 ? rows(using_numvars) : rows(using_strvars)

    // Create views on master frame
    st_framecurrent(masterframe)

    masternobs = st_nobs()
    st_addobs(usingnobs)
    
    if (rows(numvars) > 0) st_view(master_numvars = ., (masternobs + 1, masternobs + usingnobs), numvarstr)
    if (rows(strvars) > 0) st_sview(master_strvars = ., (masternobs + 1, masternobs + usingnobs), strvarstr)
    
    // Replace observations in master views with observations in using views
    if (rows(numvars) > 0) master_numvars[., .] = using_numvars
    if (rows(strvars) > 0) master_strvars[., .] = using_strvars
}


void incompatible_vars(string scalar commonvars, string scalar usingframe, string scalar masterframe)
{
    currentframe = st_framecurrent()
    t = tokens(commonvars)
    incompatible_vars = J(1, 0, "")
    for (i = 1; i <= cols(t); i++) {
        st_framecurrent(masterframe)
        numvar_master = st_isnumvar(t[i])
        st_framecurrent(usingframe)
        numvar_using = st_isnumvar(t[i])
        if (numvar_master != numvar_using) incompatible_vars = incompatible_vars, t[i]
    }
    if (cols(incompatible_vars) > 0) {
        st_local("incompatible_vars", invtokens(incompatible_vars))
    }
    st_framecurrent(currentframe)
}

end


* Version history
* 1.1.0 New features:
*       - Multiple frames can be appended by providing the frame names to using: using(f1 f2 f3 ...).
*         Wildcards are allowed in framelist, e.g., 'using(f* g??)'
*       - Option generate(name) to generate a variable that marks the origin of the observations
*         0 = master frame, 1, 2, 3, ... = frame number corresponding to the order of the frames given in
*         the `using()` option
*      Bugfixes:
*       - Previously, after appending the using frames, Stata considered the data in the master frame to be
*         sorted according to the sort variables in the master frame (if the master frame was sorted before running 
*         fframeappend) even if - because of the appended using frames - it wasn't. This could cause unexpected results,
*         e.g., in a `merge` command following fframeappend because `merge` (falsely) considered the dataset to be
*         correctly sorted. This has been fixed. Thanks to Stefan Mangelsdorf for notifying me about this issue.
* 1.0.3 Promoting variables in the master frame resulted in noisy output ("missing values created") if the
*       promoted variable contained missing values. This has been fixed. (Thanks to James Beard for informing
*       me about the issue.)
* 1.0.2 Variable types in the master frame are now promoted if the variable type of the corresponding variable
*       in the using frame is "larger".
* 1.0.1 Minor changes
* 1.0.0 Initial release