# Universal Dialog System

This document explains how popup dialogs work in FS25_NPCFavor using the `DialogLoader` pattern -- a reusable system for registering, lazy-loading, and showing FS25 GUI dialogs from a mod.

---

## Overview

FS25 provides a GUI framework built on `g_gui`, which manages dialog instances. To show a custom dialog, a mod must:

1. Create a Lua class that extends `MessageDialog`
2. Create an XML layout file defining the visual structure
3. Load the XML into `g_gui` via `g_gui:loadGui()`
4. Show the dialog via `g_gui:showDialog()`

The `DialogLoader` module (in `src/gui/DialogLoader.lua`) wraps these steps into a clean API that handles lazy loading, error recovery, and data injection.

---

## Architecture

```
DialogLoader (singleton)
    |
    |-- register(name, class, xmlPath)   -- declare a dialog exists
    |-- ensureLoaded(name)               -- lazy-load into g_gui on first use
    |-- show(name, dataMethod, ...)      -- show dialog, optionally call a setter first
    |-- getDialog(name)                  -- get instance for direct method calls
    |-- close(name)                      -- close if visible
    |-- cleanup()                        -- unload all on mod shutdown
```

### Internal Registry

Each registered dialog is stored as:

```lua
DialogLoader.dialogs[name] = {
    class    = MyDialogClass,       -- Lua class table (must have .new())
    xmlPath  = "gui/MyDialog.xml",  -- Relative path from mod root
    instance = nil,                 -- Populated on first load
    loaded   = false                -- Set to true after successful loadGui
}
```

---

## Step-by-Step: How a Dialog Gets Created

### 1. Initialization (mod load)

In `main.lua`, during `loadMap()`:

```lua
DialogLoader.init(modDirectory)
DialogLoader.register("NPCDialog", NPCDialog, "gui/NPCDialog.xml")
DialogLoader.register("NPCListDialog", NPCListDialog, "gui/NPCListDialog.xml")
```

`init()` stores the mod directory path (needed to resolve XML paths inside the mod's zip). `register()` records the class and XML path but does **not** load anything yet.

### 2. Lazy Loading (first show)

When `DialogLoader.show("NPCDialog")` is called for the first time, `ensureLoaded()` fires:

```lua
local instance = entry.class.new()              -- call NPCDialog.new()
g_gui:loadGui(modDir .. entry.xmlPath, name, instance)  -- load XML + bind to instance
```

This does three things:
- Creates a new instance of the dialog class
- Parses the XML layout and creates all GUI elements
- Binds XML element `id` attributes as properties on the instance (e.g., `id="npcNameText"` becomes `self.npcNameText`)

After loading, it verifies the dialog exists in `g_gui.guis[name]`.

### 3. Data Injection

Before showing, callers can inject data via a setter method:

```lua
-- Pass NPC data to the dialog before showing
local dialog = DialogLoader.getDialog("NPCDialog")
dialog:setNPCData(nearest, npcSystem)
DialogLoader.show("NPCDialog")
```

Or use the built-in data method parameter:

```lua
-- One-liner: calls setNPCSystem(g_NPCSystem) then shows
DialogLoader.show("NPCListDialog", "setNPCSystem", g_NPCSystem)
```

### 4. Display

`DialogLoader.show()` calls `g_gui:showDialog(name)`, which:
- Pushes the dialog onto FS25's GUI stack
- Calls `onOpen()` on the dialog instance
- The dialog renders as a modal overlay

### 5. Closing

The dialog closes when:
- The user clicks a Close button (which calls `self:close()`)
- Code calls `DialogLoader.close("NPCDialog")`
- Another dialog replaces it on the GUI stack

`onClose()` fires on the instance, allowing cleanup (e.g., unfreezing the NPC).

---

## How to Create a New Dialog

### Step 1: Write the Lua Class

Create a new file in `src/gui/`. The class must extend `MessageDialog`:

```lua
-- src/gui/MyCustomDialog.lua
MyCustomDialog = {}
local MyCustomDialog_mt = Class(MyCustomDialog, MessageDialog)

function MyCustomDialog.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or MyCustomDialog_mt)
    -- Initialize custom state here
    self.myData = nil
    return self
end

function MyCustomDialog:onCreate()
    MyCustomDialog:superClass().onCreate(self)
end

-- Data setter (called before show)
function MyCustomDialog:setMyData(data)
    self.myData = data
end

-- Called when dialog opens
function MyCustomDialog:onOpen()
    MyCustomDialog:superClass().onOpen(self)
    -- Populate GUI elements from self.myData
    if self.titleText then
        self.titleText:setText("My Custom Dialog")
    end
end

-- Button click handler (referenced from XML)
function MyCustomDialog:onClickDoSomething()
    -- Handle button click
end

function MyCustomDialog:onClickClose()
    self:close()
end

function MyCustomDialog:onClose()
    MyCustomDialog:superClass().onClose(self)
    self.myData = nil
end
```

### Step 2: Write the XML Layout

Create a matching XML file in `gui/`:

```xml
<!-- gui/MyCustomDialog.xml -->
<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<GUI onOpen="onOpen" onClose="onClose" onCreate="onCreate">
    <GuiElement profile="newLayer" />
    <Bitmap profile="dialogFullscreenBg" id="dialogBg" />

    <GuiElement profile="dialogBg" id="dialogElement" size="500px 300px">
        <ThreePartBitmap profile="fs25_dialogBgMiddle" />
        <ThreePartBitmap profile="fs25_dialogBgTop" />
        <ThreePartBitmap profile="fs25_dialogBgBottom" />

        <GuiElement profile="fs25_dialogContentContainer">
            <!-- Title -->
            <Text profile="fs25_textDefault" id="titleText"
                  position="0px -15px" text="Title" />

            <!-- Content -->
            <Text profile="fs25_textDefault" id="contentText"
                  position="0px -50px" text="" />

            <!-- Action button (3-layer pattern) -->
            <Bitmap profile="npcActionBtnBg" id="btnActionBg"
                    position="0px -100px" />
            <Button profile="npcActionBtnHit" id="btnAction"
                    position="0px -100px"
                    onClick="onClickDoSomething" />
            <Text profile="npcActionBtnText" id="btnActionText"
                  position="0px -105px" text="Do Something" />
        </GuiElement>

        <BoxLayout profile="fs25_dialogButtonBox">
            <Button profile="buttonBack" id="closeButton"
                    text="Close" onClick="onClickClose" />
        </BoxLayout>
    </GuiElement>
</GUI>
```

### Step 3: Source and Register

In `main.lua`, add the source line and register call:

```lua
-- In the source() block:
source(modDirectory .. "src/gui/MyCustomDialog.lua")

-- In loadMap(), after DialogLoader.init():
DialogLoader.register("MyCustomDialog", MyCustomDialog, "gui/MyCustomDialog.xml")
```

### Step 4: Show It

From anywhere in the mod:

```lua
DialogLoader.show("MyCustomDialog", "setMyData", someDataTable)
```

---

## The 3-Layer Button Pattern

FS25's GUI system has a limitation: standard `Button` elements don't support custom background colors or hover effects well. This mod uses a 3-layer pattern to work around this:

```
Layer 1: Bitmap (background color)     -- id="btnTalkBg"
Layer 2: Button (invisible hit target) -- id="btnTalk"
Layer 3: Text (label)                  -- id="btnTalkText"
```

All three layers are positioned identically. The Button is invisible but focusable, catching mouse events. The XML wires `onFocus` and `onLeave` to Lua handlers that change the Bitmap's color:

```xml
<Bitmap profile="npcActionBtnBg" id="btnTalkBg" position="0px -195px"/>
<Button profile="npcActionBtnHit" id="btnTalk" position="0px -195px"
        onClick="onClickTalk"
        onFocus="onBtnTalkFocus"
        onLeave="onBtnTalkLeave"/>
<Text profile="npcActionBtnText" id="btnTalkText" position="0px -200px"
      text="Talk"/>
```

The Lua side applies color changes:

```lua
function NPCDialog:applyHover(suffix, isHovered)
    if not self.buttonEnabled[suffix] then return end
    local bgElement = self["btn" .. suffix .. "Bg"]
    local textElement = self["btn" .. suffix .. "Text"]
    if bgElement then
        local c = isHovered and self.COLORS.BTN_HOVER or self.COLORS.BTN_NORMAL
        bgElement:setImageColor(c[1], c[2], c[3], c[4])
    end
    if textElement then
        local c = isHovered and self.COLORS.TXT_HOVER or self.COLORS.TXT_NORMAL
        textElement:setTextColor(c[1], c[2], c[3], c[4])
    end
end
```

This gives full control over button colors, hover states, and disabled appearance.

---

## XML Element Binding

When `g_gui:loadGui()` processes the XML, every element with an `id` attribute becomes accessible as a property on the dialog instance:

| XML | Lua Access |
|-----|-----------|
| `<Text id="npcNameText" .../>` | `self.npcNameText:setText("...")` |
| `<Bitmap id="responseBg" .../>` | `self.responseBg:setVisible(false)` |
| `<Button id="btnTalk" .../>` | `self.btnTalk` (rarely accessed directly) |

Common methods on GUI elements:
- `setText(string)` -- set text content
- `setTextColor(r, g, b, a)` -- set text color
- `setVisible(bool)` -- show/hide element
- `setImageColor(r, g, b, a)` -- set bitmap tint (for Bitmap elements)

**Important limitation:** Only direct children with `id` attributes are bound. Nested text elements inside a Button group (e.g., a Text inside a Button) may not resolve as `self["elementId"]`.

---

## Existing Dialogs

| Dialog Name | Class | XML | Trigger |
|-------------|-------|-----|---------|
| `NPCDialog` | `NPCDialog` | `gui/NPCDialog.xml` | Press E near an NPC |
| `NPCListDialog` | `NPCListDialog` | `gui/NPCListDialog.xml` | Console command `npcList` |

---

## Lifecycle Summary

```
Mod Load
  |-> DialogLoader.init(modDirectory)
  |-> DialogLoader.register("NPCDialog", NPCDialog, "gui/NPCDialog.xml")
  |   (no loading happens yet)
  |
Player presses E near NPC
  |-> DialogLoader.getDialog("NPCDialog")
  |-> dialog:setNPCData(npc, npcSystem)
  |-> DialogLoader.show("NPCDialog")
  |     |-> ensureLoaded() -- first time only
  |     |     |-> NPCDialog.new()
  |     |     |-> g_gui:loadGui("modDir/gui/NPCDialog.xml", "NPCDialog", instance)
  |     |     |-> verifies g_gui.guis["NPCDialog"] exists
  |     |-> g_gui:showDialog("NPCDialog")
  |     |-> NPCDialog:onOpen()
  |           |-> updateDisplay()
  |           |-> updateButtonStates()
  |
Player clicks Close
  |-> NPCDialog:onClose()
  |     |-> npc.isTalking = false
  |     |-> MessageDialog:onClose()
  |
Mod Unload
  |-> DialogLoader.cleanup()
        |-> close all open dialogs
        |-> nil out all instances
```

---

## Key Files

| File | Role |
|------|------|
| `src/gui/DialogLoader.lua` | Registry, lazy loader, show/close API |
| `src/gui/NPCDialog.lua` | NPC interaction dialog (5 action buttons) |
| `src/gui/NPCListDialog.lua` | NPC roster table dialog (16 rows, teleport buttons) |
| `gui/NPCDialog.xml` | NPC dialog layout + GUIProfiles |
| `gui/NPCListDialog.xml` | Roster dialog layout + GUIProfiles |
| `main.lua` | Registration calls + E-key trigger logic |
| `src/settings/NPCFavorGUI.lua` | Console command triggers for NPCListDialog |
