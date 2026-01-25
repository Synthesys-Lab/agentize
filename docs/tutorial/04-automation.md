# Developer Server and Telegram Bot Integration

In this tutorial, we will guide you to boot our development server and connect it with a Telegram bot.
As the server lauches Claude Code development session totally headlessly, [Telegram](https://telegram.org/) bot will help
you to interact with the sessions on your device to approve permissions and view progress.


## Prerequisites 1: Setup the Viewboard

Use the `\setup-viewboard` command to setup the viewboard using Github Project v2 for your repository.
Look at [project setup](./04a-project.md) for more details on how to setup the project
on both local commandline and Github.

## Prerequisites 2: Create a Telegram Bot

Before that, did you have your Telegram downloaded and registered?
If not, go to [Telegram](https://telegram.org/) and create an account.

Next, create a Telegram bot to receive messages from our development server
by following these steps:

1. Go to Telegram and search for `@BotFather` to create a new bot.
   - Start a chat with BotFather and send the command `/newbot`.
   - Follow the prompts to set a name and username for your bot.
   - After creation, BotFather will provide you with a bot token. Save this token securely. `YOUR_BOT_TOKEN`
2. Find your Telegram user ID:
   - Search for `@idbot` on Telegram.
   - Use `/getid` command to get your user ID, which should be 8 digits. Save this ID securely. `YOUR_USER_ID`
3. Configure Telegram credentials in `.agentize.local.yaml` (or `$HOME/.agentize.local.yaml` for user-wide config):

```yaml
telegram:
  enabled: true
  token: "YOUR_BOT_TOKEN"
  chat_id: "YOUR_USER_ID"
```

4. Start our local polling server using `lol serve` subcommand

```bash
lol serve --period=2m --num-workers=5
```

This command will start a local server that polls your issue board every 2 minutes and sends updates
to your Telegram bot.

Once there is:
- An issue with `agentize:plan` label and project status `Plan Accepted`, a new development session will be started.
- An issue that with `agentize:dev-req` label, a new `/ultra-planner` session will be started to generate a detailed plan.
- A PR with unmerge-able status, a `/sync-master` session will be started to rebase the PR branch onto master.
- A permission that is not determined yet, a permission request message will be sent to your Telegram bot for you to click the buttons to approve or reject.

