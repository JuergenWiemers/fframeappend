*! fframeappend 1.0.3 28feb2023 Jürgen Wiemers (juergen.wiemers@iab.de)
*! Syntax: fframeappend [varlist] [if] [in], using(framename) [force preserve]
*!
*! fframeappend ("fast frame append") appends variables from using frame 'framename'
*! to the active (master) frame.

* This program is free software under the terms of the MIT License

* Version history at bottom


program fframeappend
    version 16
    
    if !strmatch("`0'", "*using(*") {
        display as error "option 'using()' required"
        exit 198
    }

    // Get name of using frame from args to be able to
    // run 'syntax' on the using frame.
    local using_token = regexr( regexr( "`0'", "(.*)using\(", "" ) , "\).*$", "")

    frame `using_token': syntax [varlist] [if] [in], using(string) [force preserve]
    
    if ("`preserve'" != "") preserve
    
    qui frame
    local master = r(currentframe)
    
    frame `using': qui describe `varlist', fullnames varlist
    local varlist = r(varlist)
    
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
        qui gen `type' `var' = `init'
    }

    cwf `using'
    tempvar touse
    mark `touse' `if' `in'
    
    mata: append("`varlist'", "`using'", "`master'")
    
    order `mastervars', first
    if ("`preserve'" != "") restore, not
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
* 1.0.3 Promoting variables in the master frame resulted in noisy output ("missing values created") if the
*       promoted variable contained missing values. This has been fixed. (Thanks to James Beard for informing
*       me about the issue.)
* 1.0.2 Variable types in the master frame are now promoted if the variable type of the corresponding variable
*       in the using frame is "larger".
* 1.0.1 Minor changes
* 1.0.0 Initial release