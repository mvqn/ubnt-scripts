## unms-ucrm-multi
An installation script for installing UNMS and UCRM on the same host, but instead isolating both services to 
independent IP addresses available on the host.

#### Tested On:
- Vultr VPS / Debian 9 x64 / 2CPU / 4GB RAM / 80GB SSD  

#### Preparation

Before running the installer, you will need to configure two separate IP addresses for use by the UNMS and UCRM 
systems.  The examples we will use for these instructions are as follows:

```text
1.2.3.4 (for UNMS)
5.6.7.8 (for UCRM)
```

#### Installation

Simply download the script, make it executable and run using our example arguments.

Also be sure to use a valid email. 

```bash
mkdir ~/unms-ucrm-multi
cd ~/unms-ucrm-multi
wget https://github.com/mvqn/ubnt-scripts/raw/master/unms-ucrm-multi/install.sh
chmod +x install.sh
./install.sh 1.2.3.4 5.6.7.8
```

The script will take a few minutes to run and when completed, with contain numerous final instructions that should be
followed in the order displayed for the fewest issues.

#### Additional Configuration

- None

#### Notes

- Although the script was intended to be fully automated, you may be presented with a message regarding "overcommit
memory settings" or even other prompts, so user input may be required.
- This script has been tested through numerous full iterations of installation using a range of values, but has only
been tested on a very small subset of hardware and operating systems.  As I have time to test more, I will add them to
the list at the top of this page.
- If you want the most simple setup experience, I would recommend choosing hardware and an operating system that has
already been tested.

#### Warnings

- This script does not use `sudo` directly and has only been tested running directly as the root user.
- This script does not configure or alter your firewall in any way, so please be sure to lock your system down.  The
only ports these servers use are: 80, 81, 443, and 2055.
- **IMPORTANT**: Please use this script at your own risk, I am not responsible for any issues that it may cause.  As
with most other scripts of this nature, always test it in a non-production environment first.  

#### Contact Me

I can be emailed directly for further assistance at: [rspaeth@mvqn.net](mailto:rspaeth@mvqn.net) or you can submit an
issue here on GitHub at: [https://github.com/mvqn/ubnt-scripts/issues](https://github.com/mvqn/ubnt-scripts/issues).

Enjoy!