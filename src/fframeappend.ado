*! fframeappend 1.1.2 7jan2025 Jürgen Wiemers (juergen.wiemers@iab.de)
*! Syntax: fframeappend [varlist] [if] [in], using(framelist) [force preserve drop Generate(name)]
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
    qui describe, varlist
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

    // Get unexpanded varlist and extract potential `if' `in' from 'syntax' applied to first using frame
    local firstframe: word 1 of `expanded_frames'
    frame `firstframe': syntax [anything] [if] [in], using(namelist min=1) [force preserve drop Generate(name)]
    local varlist_unexpanded `anything'

    // Check existence of variables and `if'/`in' in all using frames
    foreach usingf in `expanded_frames' {
        frame `usingf': syntax [varlist] [if] [in], using(namelist min=1) [force preserve drop Generate(name)]
    }

    // Don't allow using options `preserve` and `drop` together
    if ("`drop'" != "" & "`preserve'" != "") {
        display as error "Selecting the `preserve` and `drop` options at the same time is not allowed as"
        display as error "this may cause `using` frames to be lost."
        exit 198
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

    // Check whether * or _all are in `varlist_unexpanded'; if both * and _all are given, simply use all variables.
    // -> Append all variables in all using files, no matter what else is specified in varlist
    local flag = 0
    foreach token in * _all {
        local test: list posof "`token'" in varlist_unexpanded
        if (`test') local flag = 1
    }
    if (`flag') local varlist_unexpanded = ""

    if ("`preserve'" != "") preserve

    if ("`generate'" != "")  {
        generate byte `generate' = 0
        label variable `generate' "Original frame of observations"
        label define _FFA_vl_ 0 "[0] `master'", replace 
        label values `generate' _FFA_vl_
    }

    // Loop over framelist
    local counter = 0
    foreach usingf in `expanded_frames' {
        local `counter++'
        frame `usingf': cap drop __0* // drop potential local variables in using frames
        frame `usingf': mata: st_local("has_variables", strofreal(st_nvar() > 0)) // Test if empy frame -> skip
        if (`has_variables') fframeappend_run `varlist_unexpanded' `if' `in', using(`usingf') `force'
        if ("`generate'" != "") {
            qui replace `generate' = `counter' if `generate' == .
            label define _FFA_vl_ `counter' "[`counter'] `usingf'", add
            label values `generate' _FFA_vl_
        }
        qui describe, short
        if ("`generate'" != "" & r(N) == 0) qui drop `generate'
        if ("`drop'" != "") qui frame drop `usingf'
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

    frame `using': syntax [varlist] [if] [in], using(namelist min=1) [force]

    qui frame
    local master = r(currentframe)

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
            if      ( ("`tm'" == "byte")  & inlist("`tu'", "int", "long", "float", "double") )          recast `tu' `var'
            else if ( ("`tm'" == "int")   & inlist("`tu'", "long", "float", "double") )                 recast `tu' `var'
            else if ( ("`tm'" == "long")  & inlist("`tu'", "float", "double") )                         recast double `var'
            else if ( ("`tm'" == "float") & inlist("`tu'", "long", "double") )                          recast double `var'
        }
        else { // string
            // Check for strL variables
            if (!strmatch("`tm'", "strL") & "`tu'" == "strL")                                           recast `tu' `var'
            else if ( real(subinstr("`tm'", "str", "", 1)) < real(subinstr("`tu'", "str", "", 1)) )     recast `tu' `var'
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
mata set matastrict on

void append(string scalar varlist, string scalar usingframe, string scalar masterframe)
{   
    real matrix master_numvars, using_numvars
    string matrix master_strvars, using_strvars, using_strLvars
    string rowvector vars, numvars, strvars, strLvars    
    real rowvector numtype, strLvars_indices
    real scalar i, masternobs, usingnobs
    string scalar numvarstr, strvarstr, strLvarstr

    vars = tokens(varlist)
    numtype = J(1, cols(vars), .)
    for (i = 1; i <= cols(vars); i++) {
        numtype[i] = st_isnumvar(vars[i])
    }
    
    numvars = select(vars, numtype)
    strvars = select(vars, !numtype)

    // Check strvars for strL vars
    strLvars_indices = J(1, cols(strvars), 0)
    for (i=1; i<=cols(strvars); i++) {
        if (st_vartype(strvars[i]) == "strL") strLvars_indices[i] = 1
        
        // Variable might be strL in master; then treat as strL (use st_sdata) in using.
        st_framecurrent(masterframe)
        if (_st_varindex(strvars[i]) != .) {
            if (st_vartype(strvars[i]) == "strL") strLvars_indices[i] = 1
        }
        st_framecurrent(usingframe)
    }
    strLvars = select(strvars, strLvars_indices)
    strvars = select(strvars, !strLvars_indices)

    if (cols(numvars) > 0)  numvarstr = invtokens(numvars)
    if (cols(strvars) > 0)  strvarstr = invtokens(strvars)
    if (cols(strLvars) > 0) strLvarstr = invtokens(strLvars)

    // Create views on using frame
    st_framecurrent(usingframe)

    if (cols(numvars) > 0) st_view(using_numvars = J(0, 0, .), ., numvarstr, st_local("touse"))
    if (cols(strvars) > 0) st_sview(using_strvars = J(0, 0, .), ., strvarstr, st_local("touse"))
    if (cols(strLvars) > 0) using_strLvars = st_sdata(., strLvarstr, st_local("touse"))

    usingnobs = max( ( rows(using_numvars), rows(using_strvars), rows(using_strLvars) ) )

    // Create views on master frame
    st_framecurrent(masterframe)

    masternobs = st_nobs()
    st_addobs(usingnobs)
    
    // Replace observations in master views with observations in using views
    if (cols(numvars) > 0) {
        st_view(master_numvars = ., (masternobs + 1, masternobs + usingnobs), tokens(numvarstr))
        master_numvars[., .] = using_numvars
    }

    if (cols(strvars) > 0) {
        st_sview(master_strvars = J(0, 0, ""), (masternobs + 1, masternobs + usingnobs), tokens(strvarstr))
        master_strvars[., .] = using_strvars
    }

    if (cols(strLvars) > 0) {
        st_sstore((masternobs + 1)::(masternobs + usingnobs), tokens(strLvarstr), using_strLvars)
    }
}


void incompatible_vars(string scalar commonvars, string scalar usingframe, string scalar masterframe)
{
    string scalar currentframe
    string rowvector t, incompatible_vars
    real scalar i, numvar_master, numvar_using

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
* 1.1.2 - Bugfixes:
*         - Previously, `strX' variables were not always correctly promoted to `strY' variables for X < Y. This could lead
*           to an appended string variable being truncated. This has been fixed. (Thanks to Roger Newson for reporting the issue.)
* 1.1.1 - Bugfixes:
*         - After 1.1.0, abbreviating variables in varlist didn't work anymore. This has been fixed.
*       - Improvements:
*         - Previously, if 'varlist' was specified and a given variable was missing in the n-th using frame 
*           (but not in using frames 1 to (n-1)) the first n-1 frames were appended and then an error message
*           about the missing variable was issued. Then, if option 'preserve' was also chosen, the currently
*           active using frame was restored. Now the command fails early: The existence of all variables in 'varlist'
*           in all using frames is checked before appending any using frames.
* 1.1.0 - New features:
*         - Multiple frames can be appended by providing the frame names to using: `using(f1 f2 f3 ...)`.
*           Wildcards are allowed in framelist, e.g., `using(f* g??)`.
*         - Option `generate(newvarname)` generates a labeled numeric variable that indicates the original frame
*           of the observations.
*         - Option `drop` drops appended using frames. Useful for conserving memory. Cannot be selected in combination
*           with `preserve`.
*       - Bugfixes:
*         - Variables of type `strL` in either the master or any using frame previously resulted in a runtime error. 
*           This has been fixed.
*         - Previously, after appending the using frames, Stata considered the data in the master frame to be
*           sorted according to the sort variables in the master frame (if the master frame was sorted before running 
*           fframeappend) even if - because of the appended using frames - it wasn't. This could cause unexpected results,
*           e.g., in a `merge` command following fframeappend because `merge` (falsely) considered the dataset to be
*           correctly sorted. This has been fixed. Thanks to Stefan Mangelsdorf for notifying me about this issue.
* 1.0.3 Promoting variables in the master frame resulted in noisy output ("missing values created") if the
*       promoted variable contained missing values. This has been fixed. (Thanks to James Beard for informing
*       me about the issue.)
* 1.0.2 Variable types in the master frame are now promoted if the variable type of the corresponding variable
*       in the using frame is "larger".
* 1.0.1 Minor changes
* 1.0.0 Initial release