# RotationMarker - Implementation Plan

## 1. Overview
The goal is to implement a new feature for the `Fuloh_QoL` addon named **RotationMarker**. This feature will provide two new keybinds to the user:
*   **Rotate Marker**: Places a world marker (e.g., Skull, Cross, Square) on the ground at the cursor's current 3D position. Repeated presses cycle through all 8 available markers sequentially.
*   **Clear Markers**: Instantly removes all active world markers from the world.

Because placing and clearing world markers are "protected" actions in World of Warcraft (meaning they are restricted while in combat to prevent automation), we cannot simply call Lua API functions like `PlaceRaidMarker()`. Instead, we must use Blizzard's secure UI templates (`SecureActionButtonTemplate` and `SecureHandlerClickTemplate`) coupled with macro commands (`/wm [@cursor] X` and `/cwm all`). 

## 2. Technical Approach

### The "Clear Markers" Keybind
This is the simpler of the two functionalities. We just need to trigger the `/cwm all` macro command.
1.  **Hidden Button**: Create a hidden frame named `FulohQoL_RotationMarker_ClearBtn` inheriting from `SecureActionButtonTemplate`.
2.  **Attributes**: Set its `type` attribute to `"macro"` and its `macrotext` to `"/cwm all"`.
3.  **Binding**: Direct the keybind to essentially "click" this invisible button.

### The "Rotate Marker" Keybind
Since World of Warcraft heavily restricts changing a button's `macrotext` or actions on the fly while in combat (especially recent changes in retail/11.0.0+), we must pre-create all states before combat starts.
1.  **8 Individual Marker Buttons**: Create 8 separate, hidden `SecureActionButtonTemplate` frames (`FulohQoL_RotationMarker_Btn1` to `FulohQoL_RotationMarker_Btn8`).
2.  **Pre-assigned Macros**: Assign each of these 8 buttons static macrotext: `"/wm [@cursor] 1"`, `"/wm [@cursor] 2"`, etc.
3.  **The Engine/Manager Button**: Create a primary "Manager" button named `FulohQoL_RotationMarker_CycleBtn` that inherits from `SecureHandlerClickTemplate`.
4.  **Secure Cycle Logic**: Using the `_onclick` secure snippet capability of `SecureHandlerClickTemplate`, maintain a `currentMarker` index (1 through 8). When the manager button is clicked:
    *   The secure snippet looks up the child button corresponding to `currentMarker` using `self:GetFrameRef()`.
    *   It returns this child button frame reference, effectively forwarding the hardware click securely to that specific macro button.
    *   It increments `currentMarker` (looping back to 1 after 8).

### Exposing the Keybinds in the Game UI
To allow the user to assign these actions to keys via the default **Key Bindings -> AddOns** menu, we will use a `Bindings.xml` file at the root of the addon or configure global Lua strings to trick the native interface.
*   **`Bindings.xml`**: The standard Wow addon mechanism to create graphical keybind hook-ins.
*   **Localizations**: Expose `BINDING_HEADER_FULOH_QOL`, `BINDING_NAME_FULOH_QOL_ROTATION_MARKER_CYCLE`, and `BINDING_NAME_FULOH_QOL_ROTATION_MARKER_CLEAR` to `_G` (Global) so they show up beautifully translated in the menu.

## 3. Step-by-Step Implementation

### Step 1: File Structure Updates
Create a new feature folder inside the addon:
*   `c:\World of Warcraft\World of Warcraft\_retail_\Interface\AddOns\Fuloh_QoL\Features\RotationMarker\RotationMarker.lua`
*   Create `c:\World of Warcraft\World of Warcraft\_retail_\Interface\AddOns\Fuloh_QoL\Bindings.xml` (if it does not natively exist in the root folder).

Update `Fuloh_QoL.toc` to load:
```
Features\RotationMarker\RotationMarker.lua
```

### Step 2: Bindings Configuration (`Bindings.xml`)
Create/update `Bindings.xml` to define the keys:
```xml
<Bindings>
    <Binding name="FULOH_QOL_ROTATION_MARKER_CYCLE" header="FULOH_QOL_HEADER">
        -- We will bind this click to the Manager Button
    </Binding>
    <Binding name="FULOH_QOL_ROTATION_MARKER_CLEAR">
        -- We will bind this click to the Clear Button
    </Binding>
</Bindings>
```

### Step 3: Implement Lua Logic (`RotationMarker.lua`)
1.  **Setup Global Binding Names**: Hook the localization strings via `_G` so the bindings pane reflects human-readable localized text.
    ```lua
    _G.BINDING_HEADER_FULOH_QOL_HEADER = "Fuloh's QoL"
    _G.BINDING_NAME_FULOH_QOL_ROTATION_MARKER_CYCLE = "Cycle World Marker (@Cursor)"
    _G.BINDING_NAME_FULOH_QOL_ROTATION_MARKER_CLEAR = "Clear All World Markers"
    ```
2.  **Create the Clear Button**:
    ```lua
    local clearBtn = CreateFrame("Button", "FulohQoL_RotationMarker_ClearBtn", UIParent, "SecureActionButtonTemplate")
    clearBtn:SetAttribute("type", "macro")
    clearBtn:SetAttribute("macrotext", "/cwm all")
    ```
3.  **Create the Cycle Components**:
    ```lua
    local cycleBtn = CreateFrame("Button", "FulohQoL_RotationMarker_CycleBtn", UIParent, "SecureHandlerClickTemplate, SecureActionButtonTemplate")
    
    -- Create the 8 sub-buttons and link them to the Manager via FrameRef
    for i = 1, 8 do
        local btn = CreateFrame("Button", "FulohQoL_RotationMarker_Btn"..i, UIParent, "SecureActionButtonTemplate")
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/wm [@cursor] " .. i)
        
        SecureHandlerSetFrameRef(cycleBtn, "Btn"..i, btn)
    end
    
    -- Initialize State in the restricted environment
    cycleBtn:Execute("currentMarker = 1")
    
    -- The secure forwarding click logic
    cycleBtn:SetAttribute("_onclick", [[
        local targetBtn = self:GetFrameRef("Btn" .. currentMarker)
        currentMarker = currentMarker + 1
        if currentMarker > 8 then
            currentMarker = 1
        end
        return targetBtn
    ]])
    ```
4.  **Connect Bindings to Buttons**:
    Ensure the `Bindings.xml` natively clicks these frames (Since WOW defaults allow mapping to `CLICK FrameName:MouseButton` by naming global `BINDING_NAME_CLICK ...`, but using `SetBindingClick` at load or inside `Bindings.xml` `<Binding>` definition is cleaner).

## 4. Edge Cases & Considerations
*   **Combat Taint Prevention**: All visual/attribute creations occur linearly on addon load (initialization phase), ensuring no taint is generated during combat lock-down.
*   **Frame Naming Scope**: Button frame names (`FulohQoL_RotationMarker_*`) are long and prefixed to ensure no collision with other installed addons.
*   **User Feedback**: No explicit chat-box feedback is required as the physical markers appearing on the ground instantly acts as the indicator.
