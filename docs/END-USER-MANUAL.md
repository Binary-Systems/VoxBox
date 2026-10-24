# VoxBox End User Manual

**Binary Systems, Inc.**

**VoxBox** is an Open, Simple, and Standard package for VoIP PBXs.

*Secure, Private Communication Infrastructure*

This manual is for people who place and receive calls on VoxBox. It covers the desk phone, voicemail, the User Control Panel, Polycom sets, the Quawk app, and the Zoiper softphone.

**VoxBox 2026** is the original VoxBox ISO distribution, feature set, and skin from 2007, updated for 2026. You still place calls, check voicemail, and use the desk phones. **FreePBX 17** is the administration GUI, on Asterisk 22 or 23. How the machine is built, and the administrator passwords and reset commands, are in the [VoxBox Installation Manual](INSTALLATION.md) (section 3 and section 8.2). Those accounts are not the phone password, the voicemail PIN, or the User Control Panel login.

It replaces the original *VoxBox End User Manual* (the Word card in this folder). The dial codes below are the ones shipped in the VoxBox FreePBX configuration. Your administrator can change a code under **Admin → Feature Codes**. When a code on your phone does nothing, ask which code is live, or open the Feature Codes page in the User Control Panel if that page is on your login.

Addresses in the examples are documentation addresses. Your administrator gives you the real host name or address of your PBX.

| | |
|---|---|
| Product | VoxBox 2026 |
| Publisher | Binary Systems, Inc. |
| Phone system | Asterisk, administered with FreePBX. Offices can be linked with DUNDi on UDP 4520 |
| Desk phones | Polycom SoundPoint IP 301, 501, 600, 601, and 670, VVX 500, VVX 1500, and SoundStation IP 4000 |
| Softphones | Quawk on iPhone and iPad (IAX2 push-to-talk), then Zoiper (SIP or IAX2) |
| Manual date | 23 October 2026 |

Copyright © 2007–2026 Binary Systems, Inc.

---

## 1. What your administrator gives you

Keep these separate. They are three different passwords.

| Item | What it is | Example |
|------|------------|---------|
| Extension | The number people dial to reach you | `2104` |
| Phone password | The secret Quawk, Zoiper, or an unprovisioned phone uses to register | a long random string |
| Voicemail PIN | What you type after `*97` | change this on first login |
| User Control Panel login | A web username and password, which may differ from both of the above | from your administrator |
| PBX address | Where the phone sends its registration | `192.168.50.10` on the office LAN, or `pbx.example.com` |

A Polycom that VoxBox provisions already has the extension and phone password. You still need the voicemail PIN.

The VoxBox Administration login, the database login, and the helper-web login are the administrator’s. The Installation Manual lists each default and the command that resets it. Ask the administrator when one of those accounts is the one you need. This page is only the three passwords you use on a phone or in the User Control Panel.

On a new mailbox the PIN may be the same as the extension. Change it the first time you log in (section 4). Do not leave it that way.

Emergency calls belong on a telephone your organization has tested for that purpose. Confirm with your administrator before you depend on a VoxBox extension, a Polycom, Quawk, or Zoiper to reach emergency services.

---

## 2. Everyday calling

### Call someone in the office

Dial the extension. On a Polycom, press **Dial**, press **Speaker**, or lift the handset. On Quawk, hold the talk button when **Channel** is that extension, or swipe to **Phone** and tap the green button (section 7). Zoiper places the call when you press its call button.

An extension on another VoxBox that your administrator has linked with DUNDi is dialed the same way. You do not configure DUNDi on the phone. The PBXs use UDP **4520** for that link. Your administrator sets it in the Installation Manual.

### Call an outside number

Dial the number in the form your administrator gave you. Many offices use 10 digits, or `1` and then 10 digits. Then press **Dial** or lift the handset.

### Redial

Press **Redial** on the Polycom. On Quawk, open **Phone**, then **Recents**. In Zoiper, open the call history and tap the last outgoing call.

### Answer, hold, resume

Lift the handset or press **Speaker**. To hold, press **Hold** (Polycom soft key), the hold button on Quawk’s phone page, or the hold button in Zoiper. Press the flashing line key, or **Resume**, to go back to the caller. Releasing Quawk’s talk button hangs up that push-to-talk press.

### Volume

On a Polycom, `+` and `−` during a call change the call volume. The same keys while the phone is idle change how loud it rings.

### Last number that called you

Dial `*69`. VoxBox speaks the number of the last call.

### Hear the time, or hear your own extension

| Code | What you hear |
|------|----------------|
| `*60` | The time, from the PBX clock |
| `8463` | Time of day. On a telephone keypad those digits spell TIME. |
| `*65` | Your own extension number |

### Do not disturb

Dial `*78`. New calls follow your busy or unavailable path, which is usually voicemail. Dial `*79` to turn it off. Dial `*76` to flip between on and off.

The **Do Not Disturb** key on a Polycom is the phone’s own switch. `*78` is the PBX switch. Use `*78` when you want the PBX to send calls to voicemail even if another device rings the same extension. Turn both off when you are back.

### Call waiting

Dial `*70` to allow a second call to beep while you are already on a call. Dial `*71` to refuse that second call. Answer a waiting call with the line key or with the phone’s flash / hold control.

### Call forwarding

Dial the code, then the extension or outside number that should take the calls, then `#`.

| What you want | Turn on | Turn off |
|---------------|---------|----------|
| Forward every call | `*72` | `*73` |
| Forward only when your phone is busy | `*90` | `*91` |
| Forward only when you do not answer | `*52` | `*53` |
| Flip forwarding on or off | `*96` | `*96` |

`*93`, `*94`, and `*95` are the same three forwards, and the PBX prompts you for the destination instead of taking it immediately. `*74` and `*92` clear the prompted all-calls and busy forwards.

### Follow me

If your administrator built a Follow Me list for you (ring your desk, then your mobile, then voicemail), dial `*21` to turn that list on or off.

### Pick up a coworker’s ringing phone

Dial `**` and their extension. Example: `**2108`.

Dial `*8` to pick up a call ringing in your pickup group, when your administrator has put your extension in one.

### Intercom

Dial `*80` and the extension. Their phone answers on the speaker if they allow intercom. Dial `*54` on your own phone to allow it, or `*55` to refuse it.

### Block a caller

| Code | Action |
|------|--------|
| `*32` | Blacklist the last person who called you |
| `*30` | Blacklist a number you enter |
| `*31` | Remove a number from the blacklist |

### Wakeup call

Dial `*68`. Follow the prompts for the time. This is the Hotel Wakeup service on VoxBox 2026. The original VoxBox card used `*62` for wakeup. That code is retired.

### Conference room

Dial `2663`. Enter the PIN your administrator gave you. That room is the shared conference on the restored VoxBox configuration. There is a user PIN and an administrator PIN. Ask which one you have.

### A demonstration menu

Dial `3366` for the demo auto-attendant, if your administrator has left it in place.

### Codes from the original VoxBox card

The Word manual that shipped with early VoxBox used a few codes that FreePBX 17 does not use. VoxBox 2026 follows the FreePBX codes.

| Original card | VoxBox 2026 |
|---------------|-------------|
| In-call blind transfer `##` | Still `##` |
| Directory `*411` | `411`, after your administrator creates a dial-by-name directory. The restored system has no directory until then. |
| Wakeup `*62` | `*68` |
| Simulate an incoming call `7777` | `777` |
| Record an IVR prompt `*77`, play it `*99` | Retired. Greetings are recorded in your mailbox (section 4). System recordings are made by the administrator. |
| “Festival” speaks your extension on `*65` | `*65` still speaks your extension. The voice is the PBX prompt set, not a separate Festival session. |

---

## 3. While you are already on a call

These codes are Asterisk features on the live call. Send them with the keypad. A Polycom can do the same jobs with the **Transfer** and **Conference** soft keys (section 6), which is easier on that phone.

| Code | Action |
|------|--------|
| `##` then the destination, then `#` | Blind transfer. You leave the call. The other person is connected to the destination. |
| `*2` then the destination | Attended transfer. Talk to the destination first. Hang up to complete the transfer. |
| `**` | Hang up the call you are on. |
| `*1` | Start or stop recording this call, when recording is allowed on your extension. |

### Park a call and pick it up somewhere else

1. Press **Transfer** on the Polycom, or dial `##` from Quawk’s phone keypad or from Zoiper.
2. Dial `70` and complete the transfer.
3. Listen. VoxBox speaks the parking slot. Slots on this system are `71` through `78`.
4. From any phone, dial that slot to retrieve the call.

The call waits about 45 seconds. It does not ring back to the person who parked it. If nobody picks it up, it follows the destination your administrator set for an expired park.

### Three people on one desk phone

On a Polycom, press **Conference** (labeled **Confrnc** on the SoundPoint IP), dial the next person, and press **Conference** again when they answer. For more than three parties, use conference `2663`.

---

## 4. Voicemail

VoxBox uses Asterisk voicemail, the same mailbox menu the original VoxBox card documented. FreePBX delivers it on `*97` and `*98`.

A message can be up to 5 minutes. A mailbox holds up to 100 messages. A greeting can be up to 60 seconds. The first time you open a new mailbox, the system asks you to record your name.

### Open your mailbox

| Where you are | What to dial |
|---------------|--------------|
| Your own phone | `*97`, then your PIN |
| Any other phone on this PBX | `*98`, then your extension, then your PIN |
| Someone transfers you straight to your mailbox | They blind-transfer to `*` plus your extension. You hear your greeting. Press `*` and enter your PIN. |
| The company auto-attendant | Dial `*` and your extension, wait for your greeting, press `*`, enter your PIN. |

The Messages key on a Polycom dials this same mailbox. Press **Messages**, then the connect / dial soft key, or simply dial `*97`.

If the starting PIN is your extension number, change it before you do anything else.

### While you are listening

| Key | Action |
|-----|--------|
| `1` | Play messages |
| `2` | Change folder |
| `3` | Advanced options |
| `0` | Mailbox options (greetings, name, PIN) |
| `*` | Help |
| `#` | Exit |

During a message:

| Key | Action |
|-----|--------|
| `4` | Previous message |
| `5` | Repeat this message |
| `6` | Next message |
| `7` | Delete |
| `8` | Forward to another mailbox |
| `9` | Save into a folder |
| `*` | Rewind |
| `#` | Skip ahead |

Forwarding (`8`) lets you spell a name in the directory, because directory lookup is turned on. Sending a new message to another mailbox is advanced option `3`, then `5`.

Folders, after you press `2` or after you press `9` to file a message:

| Key | Folder |
|-----|--------|
| `0` | New |
| `1` | Old |
| `2` | Work |
| `3` | Family |
| `4` | Friends |

### Greetings, your name, and your PIN

Open the mailbox and press `0`.

| Key | Action |
|-----|--------|
| `1` | Unavailable greeting. This is what callers hear when you do not answer. |
| `2` | Busy greeting. This is what callers hear when you are on the phone. |
| `3` | Record your name only. Example: “Jordan Lee.” |
| `4` | Temporary greeting. Press `1` to record it, or `2` to erase it and go back to the normal greeting. |
| `5` | Change your PIN. |
| `*` | Return to the main menu |

After you record a greeting or your name:

| Key | Action |
|-----|--------|
| `1` | Keep it |
| `2` | Listen to it |
| `3` | Record it again |

A greeting you can start from:

> You have reached voicemail for Jordan Lee. To skip this greeting, press pound. To reach someone else, press 0. Please leave your name, number, and a short message.

Callers who press `0` during your greeting go to the operator, when an operator destination is set. Callers who press `#` skip the greeting and start recording.

When a caller finishes a message, VoxBox saves it. This system does not ask the caller to review the recording.

### Email and the web

If your administrator turned on notification for your mailbox, a new message also arrives by email. You can still listen on the phone, and you can listen in the User Control Panel.

---

## 5. User Control Panel

On the office network, open the address your administrator gave you. The VoxBox login page has two icons. **User Control Panel** is the one for you. The other icon, **VoxBox Administration**, is for the administrator.

```text
http://192.168.50.10/ucp
```

Sign in with the User Control Panel username and password. That login is created in FreePBX User Manager. It is not automatically the same as your phone password or your voicemail PIN.

What you see depends on what the administrator enabled for you. Typical panels:

| Panel | What you can do |
|-------|-----------------|
| Voicemail | Play, download, or delete messages. See who called. |
| Call History | Missed, answered, and dialed calls. |
| Contacts | Names and numbers for the directory. |
| Presence / DND | Set do not disturb without dialing `*78`. |
| Call Forwarding / Follow Me | The same forwards as section 2, in a form. |
| Feature Codes | The live star codes for this PBX, including any your administrator has changed. |
| Conferences | The rooms you are allowed to open. |

A missing panel means it is not enabled on your user. Ask the administrator. It is not a fault in the phone.

---

## 6. Polycom phones

VoxBox provisions these Polycom models from Endpoint Manager: **SoundPoint IP 301, 501, 600, 601, and 670**, **VVX 500**, **VVX 1500**, and the **SoundStation IP 4000** conference phone. The steps below match the SoundPoint IP 501 procedures in the original VoxBox manual. The 301, 600, 601, and 670 use the same soft keys. The 601 and the 670 have larger displays. The 670 screen is color. The 301 has fewer keys. VVX phones use the labels on their own screens, which is covered after the SoundPoint steps.

The phone loads its extension from VoxBox when it starts. You do not type the phone password on a provisioned set. The address sticker under the phone is the MAC address. Give that sticker to your administrator if the phone never registers.

To restart a SoundPoint IP: **Menu → Settings → Basic → Restart Phone**. Unplugging the power supply for a few seconds does the same job.

### Place a call

Dial the number, then press **Dial**, press **Speaker**, or lift the handset.

### Last number redial

Press **Redial**.

### Transfer to a coworker, and talk to them first

1. Press the **Trnsfer** soft key.
2. Dial the extension.
3. Press **Send**.
4. When your coworker answers, announce the caller.
5. Press **Trnsfer** again to connect them.

If your coworker does not want the call, press **Cancel**. You are back with the original caller.

### Transfer without talking to the coworker first

1. Press **Trnsfer**.
2. Press **Blind**.
3. Dial the extension.
4. Press **Send**.

### Transfer a caller straight into voicemail

1. Press **Trnsfer**.
2. Press **Blind**.
3. Dial `*` and the mailbox number. For extension 2104, dial `*2104`.
4. Complete the transfer.

### Conference on the desk phone

1. Make or answer the first call.
2. Press **Confrnc**.
3. Dial the next person and press **Send**.
4. When they answer, press **Confrnc** again.

### Do not disturb, forward, park

| Job | On the Polycom |
|-----|----------------|
| Do not disturb | Press the **Do Not Disturb** key. Calls follow your voicemail rules. Press it again to clear. `*78` / `*79` do this in the PBX instead. |
| Forward all calls | Press **Forward**, choose the line, enter the number, press **Enable**. **Disable** turns it off. |
| Park | **Trnsfer**, dial `70`, **Send**, listen for `71`–`78`, press **Trnsfer** again. |
| Pick up a parked call | Dial the slot you were given, such as `71`. |

### Navigation keys

The round pad in the center of a SoundPoint IP is the call history and speed-dial pad. On the 501 the arrows are blue.

| Key | Opens |
|-----|--------|
| Up | Speed-dial list |
| Left | Missed calls |
| Right | Placed calls |
| Down | Received calls |

Highlight an entry and press **Dial**.

### Speed dials stored on the phone

1. Press **Directories**.
2. Press `1` for the contact directory.
3. Press **More**, then **Add**.
4. Enter the name and the number. Save.

To dial one: **Directories**, then `1`, or press the up arrow. Select the entry and press **Dial**.

PBX speed dials are separate. Dial `*75` to store one on your extension, then dial `*0` and the bin number to use it. Contact Manager speed dials use `*10`.

### Ring volume and ring tone

While the phone is idle, press `+` or `−` for ring volume.

To change the ring:

1. Press **Menu**.
2. Press `3`, `1`, `3`. That is **Settings → Basic → Ring Type** on the SoundPoint IP 501 menu. On a SoundPoint IP 670, open **Menu** and follow **Settings → Basic → Ring Type** on the display.
3. Choose the line and the ring.

### Message waiting

A red light, or a flashing line key, means you have voicemail. Press **Messages** and connect, or dial `*97`.

### VVX 500 and VVX 1500

These sets load the extension from VoxBox when they start, the same way a SoundPoint IP does. You do not type the phone password. The address sticker under the phone is the MAC address.

The jobs match the SoundPoint IP. Use the words on the VVX screen:

- Place a call with the on-screen dial key, the speaker, or the handset.
- **Transfer** and **Conference** are the labels on the display. Follow the same order as **Trnsfer** and **Confrnc** above: talk to the coworker first, or choose the blind transfer the screen offers.
- **Messages** opens voicemail. Dial `*97` when that key is not on the screen.
- Do not disturb, forward, and park use the same codes as the rest of this manual. Use the on-screen key when the phone shows one.
- Restart from **Settings → Basic → Restart Phone** when the phone shows that item. Unplugging the power supply for a few seconds does the same job.

The SoundPoint pad arrows and the `3`, `1`, `3` ring shortcut are for the SoundPoint IP. On a VVX, open the history and the ring choices from the menus on that screen.

### SoundStation IP 4000

This is the conference phone, not a handset.

- Dial the number, then press **Dial**. The microphones and the speaker are already the “handset.”
- **Mute** turns the room microphones off. Mute does not hang up.
- **Redial** repeats the last call.
- **Conference**, when that soft key is on the display, adds another party the same way as a SoundPoint IP.
- Volume keys change the room speaker.
- Voicemail, park, transfer codes, and `*97` work from the dial pad the same way as on a desk phone.
- The administrator assigns the extension in Endpoint Manager. The phone picks up that assignment from VoxBox at boot.

### If the Polycom will not register

Tell your administrator the model and the MAC address from the label. Useful checks they will make, which you can confirm out loud:

- The network cable is seated, and the phone has power.
- The phone shows the time, which means it reached the network.
- You restarted it once.

Firmware for these Polycom models is licensed software. VoxBox ships the configuration templates, including the SoundPoint IP 670, the VVX 500, and the VVX 1500. Your administrator supplies the firmware the phone is licensed to run.

---

## 7. Quawk

Quawk is the push-to-talk app for iPhone and iPad. Hold the large button to talk, and let go to hang up. Swipe to **Phone** when you want an ordinary call that stays up until someone hangs up. Quawk places both kinds of call with IAX2. Your administrator creates an IAX2 extension for the phone. Zoiper, in the next section, is a separate softphone.

Allow the microphone and local network access the first time iOS asks. The microphone is the talk path. Local network access is how the phone finds other Quawk handsets, and a VoxBox, on the same Wi-Fi.

You need an IAX2 extension and its phone password from your administrator. That password is the IAX secret. The voicemail PIN and the User Control Panel password will not register this app.

### Register to VoxBox

1. Open the gear.
2. Turn on **Use VoxBox**.
3. In **Host**, type the PBX address your administrator gave you. Example: `192.168.50.10`. A blank **Host** uses `iax.binary-systems.com`. Type the address they gave you unless they told you to leave **Host** blank.
4. Leave **Port** at `4569` unless they gave you another port.
5. Set **Extension** to your IAX2 extension and **Secret** to the phone password.
6. Leave **Dialplan context** empty unless they gave you one to type.
7. Tap **Done**. Wait until the status line says the phone is registered.

On the office Wi-Fi, open the gear and look under **Discovered**. Tap the row whose product is VoxBox. That fills in the host, turns **Use VoxBox** on, and the phone registers after the extension and secret are set. The address from **Discovered** is the office address. Away from the office, type the host name your administrator gave you. Quawk has to be able to send UDP 4569 to that host.

The phone registers again when you open Quawk, when the network changes, and shortly before the registration expires. A call that was already up usually ends when the phone moves from Wi-Fi to cellular. Call again after the status line says the phone is registered.

### Push to talk

**Channel** is the extension a press calls through VoxBox. Set it on the main screen or in the gear. Hold the large button. The screen says **Talking**. Release the button to hang up the calls that press placed.

**Channel** set to `Broadcast` reaches other Quawk phones on this same Wi-Fi. Set **Channel** to an extension number when the press should also call that extension on VoxBox.

When your administrator has turned speaker auto-answer on for a Polycom, that phone answers a push-to-talk press on its speaker. Otherwise it rings as a normal call.

A paired Apple Watch can show the same button. Hold the **Q**. The iPhone microphone is the one that transmits. Open Quawk on the iPhone if the watch says to. The watch does not place the call on its own.

### Place a normal call

1. Swipe to **Phone**, or tap that name. The gear stays between **Push to talk** and **Phone**.
2. **Use VoxBox** stays on, with **Extension** and **Secret** filled in.
3. Type the extension, or pick a favorite, a recent, or a contact. Digits, `*`, and `#` are allowed. Tap the green button.
4. The screen says **Calling** until the other person answers. Mute, speaker, hold, and the keypad are on the in-call row. The keypad sends the in-call codes in section 3, including `##` for a blind transfer.
5. Tap the red **End** button to hang up. The other person can hang up too.

An incoming phone call rings until you answer or decline. On an iPhone that is the incoming-call screen. On an iPad, Quawk shows **Answer** and **Decline**. A push-to-talk call answers by itself when the line is free. Push to talk and the phone share one line, so a press does nothing while a phone call is up.

### If Quawk will not register

| What you see | What to check |
|--------------|----------------|
| **Registered to …** | The PBX accepted the extension. Set **Channel** to the extension you want a press to call, or open **Phone** and dial. |
| **VoxBox needs an extension and secret** | Fill both in the gear. The voicemail PIN will not register the phone. |
| **Cannot find …** | The host name. On the office LAN use the internal address. Away from the office, use the name your administrator opened for you, over a path that can send UDP 4569. |
| The status stays on **Registering** | Host, port **4569**, extension, and secret. Ask the administrator to confirm this extension is IAX2 and that UDP 4569 is allowed from where you are. |

You do not pick codecs in Quawk. It offers µ-law first, then A-law. Your administrator allows those on the IAX2 extension.

---

## 8. Zoiper

Zoiper is the softphone for a computer or a mobile phone. It places normal calls over SIP or IAX2. Quawk, in the previous section, is the iPhone and iPad push-to-talk app and uses an IAX2 extension of its own.

Install Zoiper 5 for Windows, Mac, or Linux, or the Zoiper app for iOS or Android, from the publisher: [zoiper.com](https://www.zoiper.com/). When the program offers to create a Zoiper account or pick a public provider, skip that. You already have a VoxBox extension.

You need three facts from your administrator:

| Field in Zoiper | SIP extension | IAX2 extension |
|-----------------|---------------|----------------|
| Username | Your extension | Your extension |
| Password | The SIP secret | The IAX secret |
| Host | `192.168.50.10` or `pbx.example.com` | The same host |
| Protocol | SIP, UDP, port **5060** | IAX, UDP, port **4569** |

Use the SIP row unless your administrator said the extension is IAX2. VoxBox 2026 creates SIP extensions as PJSIP. Zoiper still calls that account type SIP. The phone password is the extension secret, not the voicemail PIN, and not the User Control Panel password.

On the office LAN, point Zoiper at the internal address. Away from the office, point it at the host name your administrator gave you, and only after they have opened the matching ports. SIP needs UDP 5060 and UDP 10000–20000. IAX2 needs UDP 4569.

### Zoiper 5 on Windows, Mac, and Linux

1. Open Zoiper. On the welcome screen, enter your **extension** as the username and the **phone password** as the password. Leave “Create account” alone.
2. Click **Login**.
3. If the host is empty, type the PBX address. Example: `192.168.50.10`. Click **Next**.
4. Authentication username and outbound proxy: skip both. VoxBox does not use a separate outbound proxy. If a later screen asks for an authentication username, enter the extension again.
5. Zoiper probes the host and offers the transports it found. Choose one:
   - **SIP UDP** for a normal VoxBox SIP extension.
   - **IAX UDP** for an IAX2 extension.
6. SIP TCP and SIP TLS are listed when Zoiper finds them. Use those only when your administrator told you to. The usual VoxBox SIP path is UDP on port 5060.
7. If every transport says “Not found” and the host name is correct, the phone cannot reach UDP 5060 or UDP 4569 from where you are. Finish the wizard anyway, then fix the account with the manual settings below, and ask the administrator to confirm the firewall allows your address.
8. Run the audio test, or skip it and come back. Pick the headset you will actually use. A laptop speaker next to its own microphone will echo.

Open the account afterward and confirm the network settings:

| Setting | SIP | IAX2 |
|---------|-----|------|
| Domain / host | `192.168.50.10` | `192.168.50.10` |
| Username | extension | extension |
| Password | SIP secret | IAX secret |
| Port | `5060`, or written as `192.168.50.10:5060` if the field is a single host line | `4569` |
| Transport | UDP | IAX has no SIP transport |
| STUN | Off on the office LAN | Not used |
| Use rport | On for SIP | — |

Codecs: allow **ulaw** first, then **alaw**. That matches what VoxBox expects from a softphone.

Register, then dial another extension. Two-way audio means the call path is complete. You hear the other person and they hear you.

### Zoiper on iOS and Android

1. Open **Settings → Accounts** (Android: the menu, then **Settings → Accounts**).
2. Add an account. Answer that you already have an account.
3. Choose **Manual configuration**.
4. Choose **SIP** or **IAX**.
5. Fill in the same four fields: account name (anything, for example `VoxBox`), host, username, password.
6. Skip authentication username and outbound proxy unless your administrator supplied them.
7. Let the check run, then pick **SIP UDP** or **IAX UDP** the same way as on the desktop.

On a phone, also allow Zoiper to use the microphone, and disable any battery restriction that suspends it while you expect calls. The mobile app registers only while it is allowed to run.

### If Zoiper will not register

| What you see | What to check |
|--------------|----------------|
| SIP stays unregistered | Host, extension, and SIP secret. Transport UDP, port 5060. You are on an address the PBX accepts. |
| IAX stays unregistered, SIP on a different extension works | The extension must be an IAX2 extension, port 4569, and the IAX secret. |
| IAX registers and then calls fail at once | Asterisk call tokens. VoxBox leaves **Require Call Token** on for IAX2. If this Zoiper build cannot answer that challenge, ask the administrator to turn Require Call Token off on **this extension only**. |
| You register and hear one side of the conversation only | On the LAN, STUN should be off and the PBX local network must include your subnet. Away from the office, the administrator has to set the PBX external address and allow UDP 10000–20000. |
| The wizard picked TLS | Edit the account and set SIP UDP, unless you were told to use TLS. |

Dial `*65` after you register. Hearing your extension number means the phone is on the PBX and DTMF works.

---

## 9. When something is wrong

| What you see | What to do |
|--------------|------------|
| No dial tone on a Polycom | Confirm the cable and the power. Restart the phone. If the display has no time, it has no network. Call the administrator with the model and MAC. |
| The Polycom is on the network and will not take its extension | It is not receiving a configuration from VoxBox. The administrator checks Endpoint Manager and TFTP. |
| Quawk stays on **Registering**, or asks for an extension and secret | Open the gear. **Use VoxBox** is on, **Host** is the address your administrator gave you, **Port** is **4569**, and **Secret** is the IAX phone password. |
| Zoiper says the password is wrong | Ask for the phone password again. The voicemail PIN will not register the phone. |
| Calls out fail, calls in work | The outbound route or the digits you dial. Ask how outside numbers are dialed on this system. |
| Voicemail PIN rejected | Use `*98` from another phone so you are sure which mailbox you opened. The administrator can reset the PIN. |
| A star code does nothing | Open Feature Codes in the User Control Panel, or ask the administrator. Codes in this manual are the VoxBox 2026 defaults. |
| You need a recording of a prompt for the auto-attendant | That is an administrator job in VoxBox Administration, under System Recordings. `*77` from the old card is not the current code. |

---

## 10. Names and notices

VoxBox and the Binary Systems name and marks are used by Binary Systems, Inc.

Asterisk, FreePBX, and DUNDi are trademarks of Sangoma Technologies. The phone codes in sections 2 through 5 are the FreePBX 17 feature-code set and the Asterisk in-call and voicemail menus, as shipped on VoxBox. Polycom, SoundPoint, SoundStation, and VVX are trademarks of their owner. Quawk is the Binary Systems push-to-talk app. Zoiper is a trademark of its owner. They are named here so you can use the phones. VoxBox is the system you are calling from.

The original feature card this manual replaces is `docs/VoxBox End User Manual.doc`.

Product page: <http://www.binary-systems.com/VoxBox/>

Copyright © 2007–2026 Binary Systems, Inc.
