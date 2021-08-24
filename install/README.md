This folder holds files as examples for how to install the docker image and
schedule it to run under systemd. It only runs the MiSeqQC data upload, not the
reports.

Copy each of the following files to the given directory, and review the contents.
* miseqqc_upload.service -> /etc/systemd/system
* miseqqc_upload.timer -> /etc/systemd/system
* miseqqc_upload.conf -> /etc
* crontab_mail.py -> /opt

Make sure all files are only readable by root, although crontab_mail.py doesn't
matter.

Don't put the environment variables directly in the `.service` file, because
its contents are visible to all users with `systemctl show miseqqc_upload`.

Once you install configuration files, you have to enable and start the timer.
From then on, it will start automatically when the server boots up.

    $ sudo systemctl daemon-reload
    $ sudo systemctl enable miseqqc_upload.timer
    $ sudo systemctl start miseqqc_upload.timer
    $ sudo systemctl status miseqqc_upload.timer
