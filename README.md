# Podfile tags merger

The merger allows to merge pods tags from one Podfile to another one, picking
the highest tags available.

It is useful when you have a primary app with it's main Podfile, and separate pods with their
own sandboxes (and Podfiles). You need to update these pods' Podfiles to
the newest versions from those from Podfile. This tool does it automatically.

