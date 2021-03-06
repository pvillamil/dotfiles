# Vagrant "environmental" variables.
# See https://www.vagrantup.com/docs/other/environmental-variables.html

export VAGRANT_HOME=~/lib/vagrant

# Where to store the boxes (virtual machine images).
# These get quite huge, and I want them elsewhere than Dotfiles, or my Libs
export VAGRANT_BOXES=~/vms/boxes

# Set the terminal's title bar.
function titlebar() {
  echo -n $'\e]0;'"$*"$'\a'
}

# Disable ansible cows }:]
export ANSIBLE_NOCOWS=1
