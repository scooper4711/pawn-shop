# Tagging pawns with AI

Pawn Shop can look at each pawn's art and add search keywords for what only the picture shows: the weapons it
holds, its shield and armor, notable gear and clothing, animals with it, and striking features such as wings or
horns. Searching for "scimitar shield" or "lantern" then finds pawns whose printed name says nothing of the
kind.

- **It builds on what Pawn Shop already knows.** The model is told the pawn's name and its game traits (such as
  medium, undead, mindless), and asked not to repeat them, as search finds those anyway.
- **Pawns printed without a name** also get a guess at their ancestry or kind (elf, dwarf, goblin, robot) and
  role, and a suggested name such as "Elf Wizard".
- **It never labels gender.**

**Tagging is optional, and off until you turn it on.** Without it, search still finds pawns by name, product
and trait. Tagging needs [Ollama](https://ollama.com), a free program that runs AI models on your own computer.
Pawn Shop doesn't install it for you, and nothing in Pawn Shop stops working without it.

## What you need

- **A Mac with Apple silicon** (M1 or later). Ollama also runs on Intel Macs, but far too slowly for this.
- **8 GB of memory or more.** How much you have decides which model to use; see below. To check, choose
  Apple menu ▸ About This Mac and read the Memory line.
- **Free disk space** for the model: 3 to 17 GB, depending on the model.

## 1. Install Ollama

1. Download Ollama from <https://ollama.com/download> and move it to your Applications folder.
2. Open it. A llama appears in the menu bar; that means the Ollama server is running. Ollama starts by itself
   when you log in from then on.

If you use Homebrew, `brew install ollama` and `brew services start ollama` do the same without the menu bar
icon.

## 2. Choose a model for your Mac's memory

The model is loaded into memory while pawns are being tagged, alongside everything else you have open. Choose
the largest row your Mac's memory allows:

| Your Mac's memory | Model | Download | What to expect |
|---|---|---|---|
| 8 GB | `gemma3:4b` | 3.3 GB | About twice as fast. Keywords are rougher: it lists colors and body parts, and now and then names gear that isn't in the picture. |
| 16 GB or 24 GB | `gemma3:12b` | 8.2 GB | **The default.** Pawn Shop's keywords were tuned with this model. |
| 32 GB or more | `gemma3:27b` | 17 GB | Needs about 18 GB of memory for itself. On a Mac with less than 32 GB it is unusable: minutes for each pawn. |

With 16 GB, close memory-hungry apps while a large library is tagged for the first time. If your Mac becomes
slow while tagging, use the next smaller model.

Any Ollama model that accepts pictures (a "vision" model) can be used. Pawn Shop was developed with
`gemma3:12b`. In a trial of 30 pawns on an 18 GB Mac, `gemma3:12b` took about 9 seconds a pawn and
`gemma3:4b` about 4; `gemma3:27b` did not finish a single pawn in ten minutes, so how good its keywords are on
a larger Mac is untested.

## 3. Download the model

Open Terminal (in Applications ▸ Utilities) and type, with the model you chose:

```sh
ollama pull gemma3:12b
```

This downloads the model once. To see which models you have, type `ollama list`.

## 4. Turn tagging on in Pawn Shop

1. Choose Pawn Shop ▸ Settings… and click Tagging.
2. If you chose a model other than `gemma3:12b`, type its name in the Model field and press Return.
3. Turn on **Tag pawns with AI**.

Pawn Shop starts tagging at once.

## What happens then

- **It works in the background**, one pawn at a time, while Pawn Shop is open. With `gemma3:12b` on an Apple
  silicon Mac, a pawn takes about 9 seconds, so a library of a thousand pawns takes about two and a half hours.
  You can keep using Pawn Shop, and quit whenever you like: it carries on where it stopped the next time.
- **The pawns you are looking at go first**, then pawns that need a name, then the rest.
- **A progress bar below the library** shows how far it has come; hover over it for the numbers. Settings ▸
  Tagging shows them too.
- **New pawns are tagged as you import them.**

## Using the tags

- **Search:** type keywords in the library's search field. Every word you type must appear in the pawn's
  name, product, traits or keywords; "sword" also finds "longsword".
- **See a pawn's tags:** hover over it, or select it and press Space.
- **Correct them:** choose Edit Keywords… in the pawn's preview or its context menu (Control-click). Tagging
  never changes keywords you edited, even if you change the model later.
- **Names:** pawns printed without a name wait under Library ▸ Review Unnamed Pawns…, each with a suggested
  name to accept or change.

## Changing the model

Type another model's name in Settings ▸ Tagging ▸ Model and press Return. **Every pawn is then tagged again**
with the new model, except for keywords you edited. Clear the field to go back to `gemma3:12b`.

## Using Ollama on another computer

If a more powerful computer on your network runs Ollama, Pawn Shop can use it. On that computer, let Ollama
accept connections from the network (in Ollama's settings, turn on "Expose Ollama to the network"). In Pawn
Shop, type its address in Settings ▸ Tagging ▸ Server, for example `http://studio.local:11434`, and press
Return.

- A server on your own network can use `http`. A server anywhere else must use `https`.
- The pawns' pictures are then sent to that computer. Settings says where they go.
- Clear the field to go back to this Mac (`http://localhost:11434`).

## If it doesn't work

Settings ▸ Tagging says what went wrong, and so does the warning triangle below the library.

| What it says | What to do |
|---|---|
| Ollama wasn't found at… | Ollama isn't running. Open it from Applications (look for the llama in the menu bar), then choose Library ▸ Tag New Pawns. If you changed the Server field, check the address. |
| Ollama answered "model … not found" | The model isn't downloaded, or its name is misspelled. Type `ollama list` in Terminal to see your models, and `ollama pull` with the name in the Model field to download it. |
| Tagging is turned off | Turn on Tag pawns with AI in Settings ▸ Tagging. |
| Nothing, but the Mac is slow | The model is too large for your Mac's memory. Use the next smaller one. |

A few pawns may stay without tags when the model can't describe them; Library ▸ Tag New Pawns tries those
again.

## Privacy

The pawns' pictures go only to the Ollama server named in Settings, which is your own Mac unless you change it.
Nothing is sent to the developer or to anyone else. See the [privacy policy](../PRIVACY.md).

## Turning it off, and removing it

- Turn off **Tag pawns with AI** in Settings ▸ Tagging. Tagging stops after the pawn in hand. The tags you
  already have stay, and search keeps using them.
- To free the disk space, type `ollama rm gemma3:12b` (with your model's name) in Terminal.
- To remove Ollama, quit it from its menu bar icon and move it from Applications to the Trash.
