This document is intended to help a new team member at the [BC Centre for 
Excellence in HIV/AIDS][cfe] get started on the project, so it describes how to
install tools, get source code, and connect to servers. If you are trying to
run the software at another lab, you will probably need to set up your own
servers and adjust the instructions as needed.

[cfe]: http://cfenet.ubc.ca/

## Accessing the Database ##
To run the scripts, you will need two types of access to Oracle: a test account
with full access to a test database, and a user account with read-only access
to the MiSeqQC_* tables.

You can start the process of requesting the accounts, and then move on to
installing software. You will need the Oracle client software to test your
accounts, and you will need an account to test the Oracle client software.

1. Ask the database administrator to create two accounts for you: one with
   read access to the MiSeqQC_* tables, and the other with only access to its
   own schema. This will need to be approved by
   the lab director. You will be told the default password. Also ask for
   the IP address, port, and SID for the Oracle database.

2. The account will be created with a default password. Log in for the
   first time, and change the password.

        sqlplus USER@\"//192.168.?.?:1521/SID\"

   You will be prompted to enter a new password. Oracle passwords at the
   CfE must conform to the following guidelines:
   * Password can not be same as username
   * Password must be different than previous 3 passwords
   * Password must be at least 8 characters long
   * Password must begin with letter (all letters in uppercase)
   * Password must contain at least two digits
   * Password must contain at least one punctuation !"#$%&()*+,-/:;<=>?_
       
   If you have chosen a password which fulfills all these criteria, but
   get errors about an invalid login, contact the database administrator
   and ask to set your password on her computer.
   
   After some time, you will get warned that your password will expire soon.
   Choose a new password, and then execute this SQL statement:
   
        alter user USER identified by NEW_PASSWORD replace OLD_PASSWORD;

## Setting up a developer workstation ##
This will document the installation steps to get the MiSeq QC reports running
locally on your workstation.

The steps are for Eclipse with EPIC on Ubuntu, adapt as needed to your preferred
IDE or operating system.

### Eclipse and EPIC ###
1. Eclipse runs on Java, so check the version of Java you have installed:

        java -version
 
2. If the java version is lower than 1.7, then install JDK7:

        sudo apt-get install openjdk-7-source

3. Check what version of perl you have installed. These reports were tested
   with version 5.18.2, but earlier versions may also work.

        perl -v

4. If it's not there, install it.

        sudo apt-get install perl

5. Install Eclipse, although you might prefer a more recent version from the
   [Eclipse web site][eclipse]:

        sudo apt-get install eclipse


6. Launch Eclipse. From the Help menu, choose either Eclipse Marketplace... or 
   Install New Software....

7. In the marketplace, just type EPIC and search. In the install wizard, use
   the [EPIC update site][epic].

8. From the Window menu, choose Preferences, and navigate down to Perl EPIC:
   Editor.
   * Use spaces instead of tabs.
   * Insert 4 spaces on indent.
   * Show line numbers (your choice)
   * Show print margin (your choice)

9. From the File menu, choose Import.... Navigate down to Git: Projects from Git.

10. Choose Clone URI, and paste this URI: 
   https://github.com/cfe-lab/MiSeqQCReport.git

11. Use the defaults, and choose "Import existing projects."

12. Copy the `QC_Reports/Settings_template.pm` file to `Settings.pm`, and modify
    the settings to match your environment.

[eclipse]: https://www.eclipse.org/downloads/
[epic]: http://e-p-i-c.sf.net/updates/

### Database Software ###
1. Install [Oracle Instant Client][oracle]. Use the basic lite version, and 
    test that sqlplus works by using the following command with *USER* and *SID*
    replaced by the correct values for your environment. You will probably have
    to follow the steps to set up the libraries, and you may have to run
    sqlplus64 instead of sqlplus.

        sqlplus USER@\"//192.168.?.?:1521/SID\"

    If you want to have history and tab expansion in sqlplus, install rlwrap:

        sudo apt-get install rlwrap
        alias sqlplus="rlwrap sqlplus"

    You also need to set the `ORACLE_HOME` environment variable.

        sudo vi /etc/profile.d/oracle.sh # Add the following line:
        export ORACLE_HOME=/usr/lib/oracle/12.1/client64

2. Install Perl's Database Interface package (DBI), File::Rsync, and XML::Simple.

        sudo apt-get install libdbi-perl libfile-rsync-perl libxml-simple-perl

3. Install DBD::Oracle CPAN module. The first command will begin the 
    installation of CPAN, just accept the defaults. It will eventually open a
    `cpan>` prompt where you can enter the second command. That eventually
    opens a root shell where you can enter the rest.

        sudo cpan
        look DBD::Oracle
        . /etc/profile.d/oracle.sh
        perl Makefile.PL
        make
        make test # Won't be able to connect to database, that's fine.
        make install
        exit
        exit

    If you encounter the error  "Unable to locate an oracle.mk or other
    suitable *.mk", replace "perl Makefile.PL" with "perl Makefile.PL
    -l".

4. Repeat the above commands, without the oracle.sh step, for the
    packages IPC::System::Simple, File::Rsync, and POSIX::strptime.

[oracle]: https://help.ubuntu.com/community/Oracle%20Instant%20Client

### R and StatET ###
1. Install the Cairo development library.
        
        sudo apt-get install libcairo2-dev

2. Install R. The last three commands are run in the R console, and you should
    check the [StatET installation page][statet] to see exactly which version
    of the rj package is compatible with the version of StatET you are going to
    install. You also need to install the R2HTML and Cairo packages.

        sudo apt-get install r-base r-base-dev
        sudo R
        install.packages(c("rj", "rj.gd"), repos="http://download.walware.de/rj-1.1")
        install.packages("Cairo")
        q()

2. The latest version of the R2HTML package doesn't seem to work, so you have
    download an old version.

        wget http://cran.r-project.org/src/contrib/Archive/R2HTML/R2HTML_2.2.1.tar.gz
        sudo R CMD INSTALL R2HTML_2.2.1.tar.gz

3. Launch Eclipse. For some reason, you can't currently install StatET from the
    Eclipse Marketplace, so from the Help menu, choose Install New Software....

4. Go to the [StatET installation page][statet], and find the update site for
    your version of Eclipse. Paste that address in the install wizard, and 
    select the StatET for R component. Finish the installation.

5. From the Window menu, choose Preferences. Navigate down to StatET: 
    Run/Debug: R Environments.

6. Click the Add... button.

7. Next to the Location (R_HOME) field, press the + button, and choose Try
    find automatically. It should find the R you just installed.

8. Click the Detect Default Properties/Settings button. Click OK. Click OK.

9. If you want an R console, open the Run menu, and choose 
    Run Configurations.... Select R Console and click the add button. Click Run.

10. To run an R script with command-line arguments, modify the R console 
    configuration by setting the working directory and adding this to the 
    Options/Arguments field with whatever CSV file name was created by the
    previous step:

        --args working/2014-06-25.csv

    Then you can use `source("2_generate_report.R")` in the console to launch it.

11. If you get an error about a missing font -adobe-helvetica-...,
    install the gsfonts-x11 package and refresh your font cache.

        sudo apt-get install gsfonts-x11
        xset fp rehash

12. If you need to troubleshoot versions, try the following on the server and on
    your workstation, looking particularly at the packages you installed above:

        R --version
        R
        installed.packages()[,c("Package","Version")]

13. If you have trouble with the latest R2HTML package, here's how to downgrade
    to an older version:

        sudo R CMD REMOVE R2HTML
        wget http://cran.r-project.org/src/contrib/Archive/R2HTML/R2HTML_2.2.1.tar.gz
        sudo R CMD INSTALL R2HTML_2.2.1.tar.gz

[statet]: http://www.walware.de/it/statet/installation.mframe

## Running the Software on Your Workstation ##
You will need to set up some folders with test data, and you will also want to
have a test database that you can upload the data to. See the QAI source code
for instructions on setting up the test database.

1. Create a folder for the raw data, such as `~/data/RAW_DATA/MiSeq/runs`.
2. Choose a recent run folder, and create a local copy under the raw data
    folder. You don't need all the data, just the following:
    * `Interop` folder
    * `SampleSheet.csv`
    * `RunInfo.xml`
    * `runParameters.xml` or `RunParameters.xml`
    * `needsprocessing`
3. Look at the `.conf` file in the `install` folder, and set those environment
   variables on your workstation.
4. Build the docker image from the source code, or pull the latest.
5. Create records in lab_miseq_run for each run that you are going to upload.
6. Run the docker image, as configured in the `.service` file in the `install`
   folder.

## Running the Software on the Server ##
The reports are no longer run, and the uploads are run on a docker host. See the
`install` folder for all the details.

### Releases ###
This section assumes you already have a working server up and running, and you
just want to publish a new release. Follow these steps:

1. Make sure the code works in your development environment. Also check that all
    the issues in the current milestone are closed.
2. [Create a release][release] on Github. Use "vX.Y" as the tag. If you have to
    redo a release, you can create additional releases with tags vX.Y.1, vX.Y.2,
    and so on.
3. Build the docker image, if you haven't already, then push it to docker hub.
4. Pull the docker image onto the server, and check that the version you expect
   is the latest. If not, you can explicitly tag it as `:latest`.

        ssh user@server
        sudo docker pull cfelab/miseqqc_upload:vX.Y
        sudo docker pull cfelab/miseqqc_upload:latest
        sudo docker images

5. Close the milestone for this release, create one for the next release, and
    decide which issues you will include in that milestone.

[release]: https://help.github.com/categories/85/articles
