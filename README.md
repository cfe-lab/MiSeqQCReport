How to Change QC Report Parameters
==================================

Settings for this project are stored in two files:
  - database-related settings are in Settings.pm
  - report-related settings are in the top of 2_generate_report.R


Changing the run start date
---------------------------
Open "Settings.pm" in a text editor. Look for these lines near the
bottom of the file.

        # When to start counting from.
        start_date => "01-NOV-13"

Here, "01-NOV-13" is the start date (it may be a different date in the
file). Change that to the start date you want to use, but keep the
formatting of the date the same. For example, to change the start date
to January 31, 2014, I would edit the lines to look like this.

        # When to start counting from.
        start_date => "31-JAN-14"


Changing the Westgard rules
---------------------------
Edit "2_generate_report.R", and look for the variable "westgardRules" in
the top section. The available rules are defined in the file
"westgard.R". As of this writing, all the "common" rules (taken from the
website http://www.westgard.com/mltirule.htm) were defined. Put the
functions for whichever rules you want to use in this array.

Next, edit "report.Rnw", which is an html file with some R code chunks,
to describe the new Westgard rules you are using. The relevant part is
in a <small> tag near the bottom of the body (search for Westgard).


Changing the cluster density tolerances
---------------------------------------
Edit "2_generate_report.R", and look for the variables
"clusterdensity.min" and "clusterdensity.max" in the top section. Edit
these to whatever values you like. The changes will be automatically
shown in the report (you do not need to edit "report.Rnw").


Developer notes
===============

If you are not a programmer, you do not need to read this section.

Database information
--------------------

The MiSeq QC report primarily uses information from two Oracle tables.
- MISEQQC_RUNPARAMETERS contains the reagent expration dates.
- MISEQQC_INTEROPSUMMARY contains the run parameters (CLUSTERDENSITY
  etc.)
These two tables are linked by the RUNID field. In theory, there should
be one row of MISEQQC_INTEROPSUMMARY for each row in
MISEQQC_RUNPARAMETERS, but this is not currently the case. These tables
get populated after a run is complete and Eric's Interop parsing scripts
run. Evidently, there is something wrong with the scripts.

Additionally, the LAB_MISEQ_RUN table has an entry for each run. It is
populated whenever anybody creates a new sample sheet in the QAI. Again,
there be a one-to-one relationship between LAB_MISEQ_RUN.RUNNAME
and MISEQQC_RUNPARAMETERS.EXPERIMENNAME (and by extension
MISEQQC_INTEROPSUMMARY.RUNID). However, the MISEQQC* tables get
populated by scripts after the run has completed, so it's possible that
runs don't appear there if the scripts break. 

Also, if a run is aborted, then it will be in the LAB_MISEQ_RUN table
but not in the MISEQQC* tables. Currently, it is not recorded anywhere
if a run was aborted or not.
