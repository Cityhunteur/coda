# Coda Wallet

Coda is a new cryptocurrency protocol with a lightweight, constant sized blockchain.

The Coda Wallet desktop app allows you to manage your wallets, send and receive transactions, and stake your Coda for coinbase rewards.

We have a [Discord server]( https://discord.gg/ShKhA7J)! Please come by if you
need help or have questions. You might also be interested in the [OCaml
Discord](https://discordapp.com/invite/cCYQbqN), for general OCaml help.

## Development 

The Coda Wallet is written in Reason (https://reasonml.github.io/), and built with Electron (https://electronjs.org/).

### Setup

First build the app:

1. Clone the repo via SSH: `git clone git@github.com:CodaProtocol/coda.git`
2. Navigate into coda/frontend/wallet
3. Update submodules: `git submodule update --init`
4. `yarn install` to install dependencies
5. In a separate shell, start the fake GraphQL server: `yarn run fake`
6. `yarn run query` to save results from introspection query in graphql_schema.json
7. `yarn build` to build app

Run locally with hot reloading:

1. Install watchman globally: `brew install watchman`
2. Install git lfs: `brew install git-lfs`
3. Run `git lfs install` to update hooks
4. Run `git lfs pull` to download files
5. `yarn dev` to start dev server

### Common Issues
1. If you see something like: `git@github.com: Permission denied (publickey).`
   when updating the submodules you need to set up SSH keys with GitHub, since
   our submodules use SSH URLS. GitHub has some documentation on how to do that
   [here](https://help.github.com/en/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
