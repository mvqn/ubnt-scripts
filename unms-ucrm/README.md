## unms-ucrm
An installation script for installing UNMS and UCRM on the same host, including a reverse proxy, port forwarding and certificates.

#### Tested On:
- Vultr VPS / Debian 9 x64 / 2CPU / 4GB RAM / 80GB SSD  

#### Preparation

Before running the installer, you will need to create two DNS 'A' Records pointing to your host for both servers.  The
examples we will use for these instructions are as follows:

```text
@                       example.com

unms            600     A   1.2.3.4
ucrm            600     A   1.2.3.4
```

Be sure that both records are pointing to the same host and the host is publicly accessible.

CNAME records will almost certainly also work, but have not been tested.
 

#### Installation

Simply download the script, make it executable and run using our example arguments.

Also be sure to use a valid email. 

```bash
mkdir ~/unms-ucrm
cd ~/unms-ucrm
wget https://github.com/mvqn/ubnt-scripts/raw/master/unms-ucrm/install.sh
chmod +x install.sh
./install.sh unms.example.com ucrm.example.com email@domain.com
```

The script will take a few minutes to run and when completed, with contain numerous final instructions that should be
followed in the order displayed for the fewest issues.

#### Additional Configuration

Currently, I leave the `sites-enabled/default` file in place, which will act as a fallback if other subdomains are
pointed at your host (or direct IP is used to access the host).  I have done this, in the cases where you may want to
host other subdomains or files on the host.  If this is not to your liking, here are the steps to fix it:

- Remove your default virutal host using: `rm /etc/nginx/sites-enabled/default`
- Then run `nginx -s reload`
 
Additional configuration can be done in the `unms` and `ucrm` files to suit your needs.  `default_server` may be one of
the features you need.  Please see the nginx [documentation](https://nginx.org/en/docs/) for more information.

__When the `default` file is deleted I believe that nginx actually loads them in alphabetical order for precedence, so UCRM will likely be your default.__

#### Notes

- Although the script was intended to be fully automated, you may be presented with a message regarding "overcommit
memory settings" or even other prompts, so user input may be required.
- This script has been tested through numerous full iterations of installation using a range of values, but has only
been tested on a very small subset of hardware and operating systems.  As I have time to test more, I will add them to
the list at the top of this page.
- If you want the most simple setup experience, I would recommend choosing hardware and an operating system that has
already been tested.
- Currently, NetFlow operates on port 2055 in UNMS, but had to be set to 2056 in UCRM.  Make note of this when
configuring your NetFlow device(s).


#### Warnings

- This script does not use `sudo` directly and has only been tested running directly as the root user.
- This script does not configure or alter your firewall in any way, so please be sure to lock your system down.  The
only ports these servers use are: 80, 81, 443, and 2055.
- Please make note of the "Additional Configuration" section above in regards to the default nginx configuration.
- **IMPORTANT**: Please use this script at your own risk, I am not responsible for any issues that it may cause.  As
with most other scripts of this nature, always test it in a non-production environment first.  

#### Contact Me

I can be emailed directly for further assistance at: [rspaeth@mvqn.net](mailto:rspaeth@mvqn.net) or you can submit an
issue here on GitHub at: [https://github.com/mvqn/ubnt-scripts/issues](https://github.com/mvqn/ubnt-scripts/issues).

Enjoy!