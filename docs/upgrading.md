# Upgrading netfox

Improvements are fixes are added to netfox with time, based on user feedback,
resulting in newer versions. This page is inteded to help you with upgrading
your game to a newer netfox version.

## General advice

### Have a backup

**Make sure to have a backup** of your project before upgrading. While most
often an addon update should be harmless, it is a good practice to backup your
project regularly, and specifically before risky changes.

### Disable the addon(s)

Before upgrading, disable the netfox addon(s) in your project, in Project
Settings. After the upgrade, enable the addon(s) again.

This helps with cases where an autoload or a project setting is changed.

## Version-specific steps

This section has version-specific entries where extra actions might be
necessary. Versions where the general advice holds are left out.

Make sure to apply all the steps between the versions, e.g. if you're updating
from 1.0.0 to 1.3.0, refer to the sections between the two versions, in this
case v1.1.1. If there are no sections here for your version range, that means
that the upgrade should need no extra action, aside from replacing the old
netfox addon(s) with the new one(s).

### v1.1.1

* Remove `Interpolators` from the project autoloads, it's a static class now.

