Setting up a developer workstation
==================================

This will document the installation steps to get the MiSeq QC reports running
locally on your workstation.

The steps are for Eclipse with EPIC on Ubuntu, adapt as needed to your preferred
IDE or operating system.

1. Check the version of Java you have installed:

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

   [eclipse]: https://www.eclipse.org/downloads/

6. Launch Eclipse. From the Help menu, choose either Eclipse Marketplace... or 
   Install New Software....

7. In the marketplace, just type EPIC and search. In the install wizard, use
   the [EPIC update site][epic].
   [epic]: http://e-p-i-c.sf.net/updates/

7. From the Window menu, choose Preferences, and navigate down to Perl EPIC:
   Editor.
   * Use spaces instead of tabs.
   * Insert 4 spaces on indent.
   * Show line numbers (your choice)
   * Show print margin (your choice)

8. From the File menu, choose Import.... Navigate down to Git: Projects from Git.

9. Choose Clone URI, and paste this URI: 
   https://github.com/cfe-lab/MiSeqQCReport.git

10. Ask your supervisor for the password, and use the defaults for everything 
    else. Select the new project wizard with a Perl project.

11. Change the folder to point at the new miseq_qc_report folder created by git,
    and finish the import.

12. Install [Oracle Instant Client][oracle]. Use the basic lite version, and 
    test that sqlplus works. You will probably have to follow the steps to set 
    up the libraries, and you may have to run sqlplus64 instead of sqlplus.

        sqlplus USER@\"//192.168.?.?:1521/SID\"

    If you want to have history and tab expansion in sqlplus, install rlwrap:

        sudo apt-get install rlwrap
        alias sqlplus="rlwrap sqlplus"

    You also need to set the `ORACLE_HOME` environment variable.

        sudo vi /etc/profile.d/oracle.sh # Add the following line:
        export ORACLE_HOME=/usr/lib/oracle/12.1/client64

    [oracle]: https://help.ubuntu.com/community/Oracle%20Instant%20Client

13. Install Perl's Database Interface package (DBI), File::Rsync, and XML::Simple.

        sudo apt-get install libdbi-perl libfile-rsync-perl libxml-simple-perl

14. Install DBD::Oracle CPAN module. The first command will begin the 
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

14. Repeat the above commands, without the oracle.sh part, for the
    packages IPC::System::Simple, File::Rsync, and POSIX::strptime.

14. Copy the `QC_Reports/Settings_template.pm` file, and modify the settings to
    match your environment.

14. Install the Cairo development library.
        
        sudo apt-get install libcairo2-dev

15. Install R. The last two commands are run in the R console, and you should
    check the [StatET installation page][statet] to see exactly which version
    of the rj package is compatible with the version of StatET you are going to
    install. You also need to install the R2HTML and Cairo packages.

        sudo apt-get install r-base r-base-dev
        sudo R
        install.packages(c("rj", "rj.gd"), repos="http://download.walware.de/rj-1.1")
        install.packages("R2HTML")
        install.packages("Cairo")
        q()

    [statet]: http://www.walware.de/it/statet/installation.mframe

16. Launch Eclipse. For some reason, you can't currently install StatET from the
    Eclipse Marketplace, so from the Help menu, choose Install New Software....

17. Go to the [StatET installation page][statet], and find the update site for
    your version of Eclipse. Paste that address in the install wizard, and 
    select the StatET for R component. Finish the installation.

18. From the Window menu, choose Preferences. Navigate down to StatET: 
    Run/Debug: R Environments.

19. Click the Add... button.

20. Next to the Location (R_HOME) field, press the + button, and choose Try
    find automatically. It should find the R you just installed.

21. Click the Detect Default Properties/Settings button. Click OK. Click OK.

22. If you want an R console, open the Run menu, and choose 
    Run Configurations.... Select R Console and click the add button. Click Run.

23. To run an R script with command-line arguments, modify the R console 
    configuration by setting the working directory and adding this to the 
    Options/Arguments field with whatever CSV file name was created by the
    previous step:
    
        --args working/2014-06-25.csv
    
    Then you can use `source("2_generate_report.R")` in the console to launch it.

24. If you get an error about a missing font -adobe-helvetica-...,
    install the gsfonts-x11 package and refresh your font cache.

        sudo apt-get install gsfonts-x11
        xset fp rehash

The reports are currently run on a virtual machine by a certain user,
and then displayed on the local network. They are scheduled under that
virtual machine's user's crontab at 8:00 AM each day. You can see the
tasks by logging in as that user and then typing `crontab -l`. For the
IP addresses of the machine, and the user as whom you must log on, ask
your supervisor.


Setting up Oracle
=================

To run the scripts, you will need access to certain Oracle tables.

1. Ask the database administrator to create an account for you, with
   read access to the MiSeqQC_* tables. This will need to be okayed by
   the lab director. You will be told the default password. Also ask for
   the IP address, port, and SID for the Oracle database.

2. The account will be created with a default password. Log in for the
   first time, and change the password.

        sqlplus username/password@//dbhost:1521/SID

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
