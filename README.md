# xrb-druglab
esx #esx qbcore #qbox #qbcore #fivem #server

https://youtu.be/AswnZDLuEpY?si=GGDrv9BqT3LUFMkI

* **Download MLO** **Meth, Coke, Weed**
https://github.com/xrb-script/cokemethweed-MLO

*   **Drug Lab Management System:** This script allows players to buy, sell, and manage laboratories for producing various drugs on a FiveM server (compatible with ESX and QBCore).
*   **Buying and Selling Labs:**
    *   Players can find and purchase unowned labs through map interactions (using `ox_target`).
    *   Lab owners can sell their labs back to the system for a percentage of the original price.
*   **Drug Processing System:**
    *   Players can deposit raw materials (unprocessed drugs) into the lab's stash.
    *   **Automatic Processing:** If the amount of raw material reaches a certain threshold (e.g., 500 units), the system automatically processes it into packaged product.
    *   **Manual Processing:** If the amount is below the threshold, the player must manually interact with a specific point in the lab to start processing (with a progress bar).
*   **Lab Stash:**
    *   Labs have an internal stash for raw materials and packaged products.
    *   Players with access can deposit raw materials and withdraw packaged products.
*   **Access Permissions (Keys):**
    *   Lab owners can give "keys" (access permissions) to other players.
    *   Each lab has a maximum number of keys that can be issued (e.g., 5).
    *   Owners can revoke given keys.
    *   Players with keys can access the stash and perform manual processing.
*   **Admin Panel (`/adminlab`):**
    *   Administrators with the appropriate permissions can use the `/adminlab` command to open a management panel.
    *   **Create New Labs:** Admins can create new labs at their current location, specifying the drug type and price.
    *   **View and Manage Active Labs:** Admins can see a list of all labs, their details (owner, stock), who has keys, and can delete/reset labs.
    *   **Revoke Keys (by Admin):** Admins can remove any player's key from any lab.
    *   **Edit Stash/Process Positions:** Admins can reposition the Stash and Process interaction points for any existing lab.
    *   **Edit MLO Location:** The admin can set the Lab coordinates for each Lab he creates, the Entry, the Exit

*   **Framework Compatibility (ESX/QBCore):**
    *   The core logic is adapted to work with both frameworks, configured via `Config.Framework`.
*   **Database:** Uses a single table (`drug_labs`) to store all lab information.
*   **Notifications and Blips:** Provides notifications for various actions and map blips to indicate lab locations and statuses (owned, unowned, keyed).
