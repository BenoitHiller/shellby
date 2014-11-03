# Shellby

Shellby is an IRC bot built mostly in bash script. This allows you to write handlers that work on the IRC input as a stream, with stdout being sent to the IRC server.

# Motivation

> Yeah, yeah, but your [developers] were so preoccupied with whether or not they could that they didn't stop to think if they should.
>
> Dr. Ian Malcolm

# Usage

Edit `config` file with appropriate values then run `bin/shellby`.

If you register the account for the bot you can add a `etc/password` file containing just the nickserv password and it will auth itself on join.

## Dependencies

* netcat
* gawk 
* bash >=4
