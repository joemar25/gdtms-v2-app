/**
 * ============================================================================
 * ITMS MOBILE APP - USER MANUAL UNIFORM JSON DATA
 * ============================================================================
 * This file serves as the database of content for the user manual.
 * It is written as a global javascript variable so that it can be loaded 
 * in local browsers (via the file:// protocol) without CORS blocking errors.
 * 
 * Version is based on pubspec.yaml (version: 1.0.7+1).
 * Sections are strictly structured to match the user's requested index,
 * designed with 100% friendly, non-technical language tailored to couriers.
 */

window.MANUAL_DATA = {
  version: "1.0.7",
  buildNumber: "1",
  brandName: "ITMS",
  logoPath: "../../assets/images/app_icon.png",
  
  // Document version history to support manual versioning
  docHistory: [
    {
      version: "v1.0.7",
      date: "June 01, 2026",
      changelog: "Simplified manual descriptions, removed computer technical terms, re-organized sections logically into onboarding (Getting Started) and standard operations (Delivery Flow). Mapped out location/GPS permissions, Initial Sync loading steps, and re-introduced active package checklists."
    },
    {
      version: "v1.0.6",
      date: "May 18, 2026",
      changelog: "Updated wallet payment cards and layout integrations to match premium design system tokens."
    },
    {
      version: "v1.0.0",
      date: "April 15, 2026",
      changelog: "Initial user manual launch covering login, remember credentials, and standard delivery workflows."
    }
  ],
  
  sections: [
    // 1. Login
    {
      id: "sec-login",
      category: "Getting Started",
      title: "Login",
      lead: "Logging into the app is the very first step to start your delivery day. The app automatically remembers your username so you can get moving quickly.",
      steps: [
        {
          number: "1",
          title: "Phone & Password Input",
          text: "Type in your registered <strong>Phone Number</strong> and password. Tap the <span class=\"key-badge\">(Eye Icon)</span> next to the password box to see your letters and avoid typing mistakes."
        },
        {
          number: "2",
          title: "Automatic Number Memory",
          text: "You do not need to tick any checkboxes! The app **automatically remembers** your last successfully logged-in Phone Number. When you open the app tomorrow morning, your phone number will already be filled in for you!"
        },
        {
          number: "3",
          title: "Select Bright or Dark Look",
          text: "Look at the top-right corner of the screen. Tap the circular <span class=\"key-badge\">(Sun/Moon Toggle)</span> to switch between Light and Dark mode. Dark mode is perfect for night deliveries to rest your eyes and save phone battery."
        },
        {
          number: "4",
          title: "Having Trouble? Contact Your Admin!",
          text: "If you cannot log in or forgot your password, don't worry! Look at the bottom of the screen. Tap <strong>Contact your admin</strong> to pull up a helpful sheet showing your coordinator's call hotline. Tap to call directly."
        }
      ],
      screenshot: {
        label: "📸 Add Login Screen Screenshot",
        dimensions: "Size: 320x640px"
      }
    },

    // 2. Mandatory Permissions
    {
      id: "sec-permissions",
      category: "Getting Started",
      title: "Mandatory Permissions",
      lead: "Before you can view your dashboard, your phone will prompt you for permissions. You must allow these for the app to function properly:",
      steps: [
        {
          number: "1",
          title: "Location (GPS) - Always Allow",
          text: "The app tracks coordinates to verify you are at the correct address when completing a delivery. If location services are disabled, the app displays a 'Location Permission Required' screen. Tap <strong>Grant Permission</strong> or <strong>Open Settings</strong> to enable it."
        },
        {
          number: "2",
          title: "Camera - Allow",
          text: "The app uses your camera to scan parcel barcodes, capture Proof of Delivery (POD) photos, and take selfie verifications. When prompted, tap <strong>Allow</strong>."
        },
        {
          number: "3",
          title: "Notifications - Allow",
          text: "Enables immediate alerts for dispatch assignments, payouts, and coordinator updates. Tap <strong>Allow</strong> when the prompt appears."
        },
        {
          number: "4",
          title: "App Updates (Install Permission)",
          text: "On Android devices, the app will ask for permission to install updates. This allows the app to automatically install new versions and features safely so you never miss a revision!"
        }
      ],
      alerts: [
        {
          type: "danger",
          text: "<strong>🚨 GPS Warning:</strong> Keep your phone's GPS location turned ON at all times during your shift. The app relies on GPS to protect your delivery proofs and confirm your payouts!"
        }
      ]
    },

    // 3. First-Time App Setup (Initial Sync)
    {
      id: "sec-sync",
      category: "Getting Started",
      title: "First-Time App Setup (Initial Sync)",
      lead: "Once permissions are granted, the app performs a first-time setup when you log in for the very first time. You will see a loading screen titled <strong>Setting Up Your App</strong> with a bouncing blue indicator.",
      steps: [
        {
          number: "1",
          title: "Downloading Your Work",
          text: "The app is downloading your assigned dispatches, parcel addresses, and customer names directly onto your phone. This is your <strong>Initial Sync</strong>!"
        },
        {
          number: "2",
          title: "Complete Offline Support",
          text: "Once this download finishes, all your work is securely saved inside your phone. You are now ready to deliver, scan barcodes, and capture photo proofs even in areas with zero cell reception or no internet!"
        },
        {
          number: "3",
          title: "Auto-Redirect",
          text: "When completed, a green checkmark appears and the app opens your dashboard automatically after 3 seconds (or you can tap the <strong>Continue</strong> button to start immediately)."
        }
      ],
      screenshot: {
        label: "📸 Add App Setup Screenshot",
        dimensions: "Size: 320x640px"
      }
    },

    // 4. Accepting Dispatch
    {
      id: "sec-accepting-dispatch",
      category: "Deliveries Flow",
      title: "Accepting Dispatch",
      lead: "Once the first-time setup is complete and you are logged in, you must accept dispatches assigned to you by your coordinator before you start loading your vehicle. This downloads the latest parcel addresses and barcodes so you can deliver offline.",
      tabs: [
        {
          tabId: "disp-std",
          tabBtnLabel: "Standard Dispatch",
          title: "Accepting Standard Deliveries",
          lead: "Standard dispatches represent individual packages assigned to your route for direct home delivery.",
          steps: [
            {
              number: "1",
              title: "Open Pending Batches",
              text: "Navigate to your <strong>Dispatch List</strong> on the screen. You will see a list of assigned batches waiting for you."
            },
            {
              number: "2",
              title: "Review & Download",
              text: "Review the total parcel count, and tap the green <strong>ACCEPT DISPATCH</strong> button. The app will securely download all delivery details into your phone."
            }
          ],
          alerts: [
            {
              type: "info",
              text: "<strong>💡 Quick Tip:</strong> Once accepted, these dispatches move into the app's safe offline storage. You can view addresses and scan parcels even in areas with zero cell reception!"
            }
          ]
        },
        {
          tabId: "disp-bagsakan",
          tabBtnLabel: "Bagsakan Dispatch",
          title: "Accepting Bagsakan Groups",
          lead: "Bagsakan dispatches represent bulk shipments bundled together for one large single drop-off point.",
          steps: [
            {
              number: "1",
              title: "Look for the Bagsakan Tag",
              text: "Look for dispatches highlighted with a bright <strong>BAGSAKAN</strong> tag in your dispatch list."
            },
            {
              number: "2",
              title: "Download the Group",
              text: "Tap the green <strong>ACCEPT DISPATCH</strong> button on the Bagsakan dispatch. All bundled parcels are safely downloaded and moved into your special Bagsakan list so they don't clutter your regular delivery screen."
            }
          ]
        },
        {
          tabId: "disp-reject",
          tabBtnLabel: "Rejecting Dispatch",
          title: "Rejecting a Dispatch",
          lead: "If a dispatch is assigned to you by mistake or contains incorrect items, you can decline it before downloading.",
          steps: [
            {
              number: "1",
              title: "Tap Reject",
              text: "Tap the red <strong>REJECT DISPATCH</strong> button at the bottom of the dispatch details page."
            },
            {
              number: "2",
              title: "Select Rejection Reason",
              text: "Choose the correct reason from the dropdown list: <strong>RECIPIENT NOT AVAILABLE</strong>, <strong>INVALID / INCOMPLETE ADDRESS</strong>, <strong>DAMAGED DOCUMENTS</strong>, <strong>DUPLICATE DISPATCH</strong>, <strong>OUTSIDE ASSIGNED AREA</strong>, <strong>SAFETY CONCERN</strong>, or <strong>OTHERS (SPECIFY)</strong>."
            },
            {
              number: "3",
              title: "Write Remarks & Confirm",
              text: "Add any optional notes in the <strong>REMARKS</strong> box, then tap <strong>REJECT DISPATCH</strong> and confirm to return it to the sorting hub."
            }
          ]
        }
      ]
    },

    // 5. For Deliveries
    {
      id: "sec-for-deliveries",
      category: "Deliveries Flow",
      title: "For Deliveries",
      lead: "Once dispatches are accepted, they are automatically placed into your active delivery list under the **For Deliveries** status. This is your main daily checklist.",
      steps: [
        {
          number: "1",
          title: "Accessing the List",
          text: "Tap <strong>DELIVERIES</strong> on your dashboard stats or navigate to the deliveries tab. You will see a clean card for every package currently loaded in your vehicle."
        },
        {
          number: "2",
          title: "Reviewing Package Cards",
          text: "Each card displays the customer's account name, sequence, due date, and due-time. Look for the sequence indicators to organize your package loading order."
        },
        {
          number: "3",
          title: "Search & Filter",
          text: "Type an address, name, or barcode in the top search bar to instantly find any package in your list."
        },
        {
          number: "4",
          title: "Package Details Sheet",
          text: "Tap any package card to pull up a full-screen details view. Here, you can review the product type, sequence number, and read <strong>Special Instructions</strong> left by sorting operators."
        },
        {
          number: "5",
          title: "Start Delivery Update",
          text: "Tap the green <strong>UPDATE STATUS</strong> button at the bottom of the package details sheet to begin updating the delivery record."
        }
      ],
      screenshot: {
        label: "📸 Add Package List Screenshot",
        dimensions: "Size: 320x640px"
      }
    },

    // 6. Update Deliveries
    {
      id: "sec-update-deliveries",
      category: "Deliveries Flow",
      title: "Update Deliveries",
      lead: "When you hand over a package to a customer, select this status. You must satisfy the FSI Delivered checklist to complete the delivery:",
      steps: [
        {
          number: "1",
          title: "Recipient Name",
          text: "Type in the exact name of the person who physically took the package."
        },
        {
          number: "2",
          title: "Recipient Relationship",
          text: "Tap to select how they are related to the addressee: <strong>OWNER, SPOUSE, SIBLING, PARENT, CHILD, HOUSEHOLD_HELP, CO_WORKER, SECURITY_GUARD, or OTHERS</strong>. If you choose <strong>OTHERS</strong>, you are required to type in their exact relationship in the field below."
        },
        {
          number: "3",
          title: "Placement Type",
          text: "Choose where the parcel was left: <strong>RECEIVED</strong> (directly handed over), <strong>MAILBOX</strong>, <strong>INSERTED - DOOR</strong>, or <strong>INSERTED - WINDOW</strong>."
        },
        {
          number: "4",
          title: "Required Photos",
          text: "You must capture two separate photos using your phone's camera:<br>• <strong>POD Photo:</strong> A clear photo of the package at the placement spot.<br>• <strong>Selfie Photo:</strong> A quick selfie showing you at the delivery location."
        },
        {
          number: "5",
          title: "Confirmation Code",
          text: "Input the **6-character alphanumeric code** printed on the customer's delivery slip."
        },
        {
          number: "6",
          title: "Quick Remarks & Signature Pad",
          text: "Tap any of the active quick preset chips (remarks) to write notes instantly. If required, check the signature box to capture the customer's signature on a full-screen signature canvas."
        }
      ],
      screenshot: {
        label: "📸 Add POD Update Screen Screenshot",
        dimensions: "Size: 320x640px"
      }
    },

    // 7. Deliveries (Scanner & Navigation)
    {
      id: "sec-deliveries",
      category: "Deliveries Flow",
      title: "Deliveries (Scanner & Navigation)",
      lead: "The Deliveries tab displays your active deliveries. Learn how to navigate your list and use the scanning tools:",
      steps: [
        {
          number: "1",
          title: "Page-by-Page Navigation",
          text: "If you have many packages, they are split into separate pages. Use the arrows at the bottom to flip pages. Flipping pages keeps your scroll position so you never get lost!"
        },
        {
          number: "2",
          title: "The Scanner Layout",
          text: "Tapping the QR scan icon in the header opens your phone camera. Depending on what you are doing, the header will say <strong>Scan POD</strong>, <strong>Scan Dispatch</strong>, or <strong>Scan Bagsakan</strong>. Here is what you will see perfectly:<br>• **Flashlight Switch:** Tap the flashlight icon in the top-right corner to toggle your phone's physical flash for night scans.<br>• **Viewfinder Window:** A transparent scanner square in the center with bright green brackets on the corners and an animated colored scanning line moving up and down.<br>• **Manual Entry Button:** An outlined button at the bottom labeled **ENTER MANUALLY** with a keyboard icon. Tap it to type barcodes manually if a label is torn.<br>• **Warning Alerts:** If you scan a parcel that isn't assigned to you, a red warning alert box pops up showing why it is blocked."
        },
        {
          number: "3",
          title: "Pending Sync Lock Badge",
          text: "If you updated a delivery offline and it is waiting to sync, you will see a blue **PENDING SYNC** badge on the card. This card is locked—you cannot edit it while it is uploading to protect your work."
        }
      ],
      screenshot: {
        label: "📸 Add Barcode Scanner Screenshot",
        dimensions: "Size: 320x640px"
      }
    },

    // 8. ReDelivery (Failed Delivery)
    {
      id: "sec-redelivery",
      category: "Deliveries Flow",
      title: "ReDelivery (Failed Delivery)",
      lead: "If a package cannot be delivered, update the status to FAILED. The app will prompt you for information to schedule a redelivery:",
      steps: [
        {
          number: "1",
          title: "Non-Delivery Reason",
          text: "Choose why the delivery failed from the searchable dropdown picker (e.g. *Recipient Absent, Closed Office, Address Incorrect, Refused to Accept*). If choosing \"Others\", typing a reason is mandatory."
        },
        {
          number: "2",
          title: "Name of Informant (According To)",
          text: "Type in the name of the informant (e.g. security guard, housemate, neighbor) who provided the non-delivery reason."
        },
        {
          number: "3",
          title: "Selfie Proof",
          text: "Take a location selfie at the customer's address to verify your arrival."
        },
        {
          number: "4",
          title: "Redelivery Lists",
          text: "Failed deliveries go to the Failed Delivery list and are split into two sub-filters: **For Redelivery** (items to retry later) and **For Return** (items going back to the hub)."
        }
      ]
    },

    // 9. Misrouted
    {
      id: "sec-misrouted",
      category: "Deliveries Flow",
      title: "Misrouted",
      lead: "Mark a parcel as MISROUTED if you arrive and discover that the package's address belongs to a completely different municipality or zone that is outside your assigned route.",
      steps: [
        {
          number: "1",
          title: "Mailpack Photo",
          text: "Take a clear picture of the mailpack barcode and address label so sorting coordinators can redirect it immediately."
        },
        {
          number: "2",
          title: "Remarks",
          text: "Tap preset remarks or write details (e.g., \"Address is in Sector 4, not my Sector 2\") to help sorting hubs redirect the parcel correctly."
        }
      ]
    },

    // 10. Bagsakan - Propagation - Submission
    {
      id: "sec-bagsakan",
      category: "Deliveries Flow",
      title: "Bagsakan - Propagation - Submission",
      lead: "Bagsakan groups let you complete dozens of drop-off items at once by updating just one. Follow this exact workflow:",
      steps: [
        {
          number: "1",
          title: "Select Your Bagsakan Group",
          text: "Navigate to your **Bagsakan** tab from the bottom menu, and tap on your assigned group name to see the list of bundled packages."
        },
        {
          number: "2",
          title: "Complete One Delivery (The Source)",
          text: "Tap on exactly **ONE** package from the group. Fill out its delivery checklist (photos, recipient details, signature, confirmation code) and submit it. This package becomes your **cloning source**!"
        },
        {
          number: "3",
          title: "Remove Returned Parcels",
          text: "Before finishing, look at your list. If there are any packages in the group that you were unable to deliver (e.g. they need to be returned), tap the **Trash Icon** on that package's card. This removes it from the group and returns it to your standard delivery list so its status is not copied."
        },
        {
          number: "4",
          title: "Tap Submit Bagsakan",
          text: "Once your source package is successfully updated, a large gradient button labeled **SUBMIT BAGSAKAN** will appear at the bottom of your screen. Tap this button to begin."
        },
        {
          number: "5",
          title: "Confirm Data Cloning (Propagation)",
          text: "A popup box will ask: <em>\"Submit Bagsakan? This will propagate delivery data to all items in the group...\"</em> Tap **Submit**. The app will instantly copy and paste the recipient name, photo proofs, customer signature, and delivery details from your single source package to **ALL** remaining packages in the group!"
        },
        {
          number: "6",
          title: "Permanent Lock & 1-Day Auto-Purge",
          text: "Submitting is final. The entire group is immediately locked for safety. The completed Bagsakan group card remains visible on your screen for **exactly 1 day** so you can review it, after which the app automatically cleans and purges it to save phone memory."
        }
      ],
      alerts: [
        {
          type: "warning",
          text: "<strong>⚠️ Protection Rule:</strong> Items marked as the 'Propagation Source' cannot be removed from the group, protecting data integrity during cloning."
        }
      ],
      screenshot: {
        label: "📸 Add Bagsakan Workflow Screenshot",
        dimensions: "Size: 320x640px"
      }
    },

    // 11. Wallet - Request and Consolidation
    {
      id: "sec-wallet",
      category: "Earnings",
      title: "Wallet - Request and Consolidation",
      lead: "Manage your hard-earned payouts transparently. The Wallet tab breaks down your pay, handles payout requests, and triggers automatic consolidation.",
      alerts: [
        {
          type: "info",
          text: "<strong>💰 Pay Tokens & Colors:</strong><br>• <strong>Gross Earnings:</strong> Your base payout amount.<br>• <strong>Penalties (Red):</strong> Deductions for delays or client complaints.<br>• <strong>Coordinator Incentive (Orange):</strong> Coordinator administration deductions.<br>• <strong>Net Payable (Large Green text):</strong> Your actual final payout balance!"
        }
      ],
      steps: [
        {
          number: "1",
          title: "Submit a Payout Request",
          text: "Tap the **Request Payout** button on the Wallet screen. A confirmation dialog will pop up showing your Net Payable inside a highlight green card."
        },
        {
          number: "2",
          title: "Confirm & Send",
          text: "Double-check your gross pay, penalties, and date range, then click <strong>Confirm & Submit</strong> to send the request to the coordinator team for review."
        },
        {
          number: "3",
          title: "Automatic Payout Consolidation",
          text: "If your previous payout request is still **PENDING** (not yet approved) and you complete **new eligible deliveries**, the app automatically merges them! This triggers the **Consolidation Warning Banner**."
        },
        {
          number: "4",
          title: "Reference Code Retention",
          text: "Consolidation merges the new pay safely into the pending request. It **preserves your unique Reference Code** while dynamically updating your total volumes and increasing your final Net Payable amount."
        }
      ],
      screenshot: {
        label: "📸 Add Wallet Payout Screenshot",
        dimensions: "Size: 320x640px"
      }
    },

    // 12. Settings - Update
    {
      id: "sec-settings-update",
      category: "Preferences",
      title: "Settings - Update",
      lead: "Update app preferences, manage legal documents, and download application revisions inside your Profile settings screen:",
      tabs: [
        {
          tabId: "pref-settings",
          tabBtnLabel: "App Settings & History",
          title: "Configuring Your Mobile App",
          lead: "Customize your settings to keep your phone storage clean and fast.",
          steps: [
            {
              number: "1",
              title: "Sync History Retention",
              text: "Tap <strong>Profile → Preferences → Sync History</strong> to configure how long completed deliveries remain on your screen: **1 Day, 3 Days, or 5 Days**. The app automatically runs cleanups on startup."
            },
            {
              number: "2",
              title: "Download App Updates",
              text: "Tap the **Update App** button on the settings sheet to check for revisions. This is active only when connected to a **stable internet network** (Wi-Fi/Strong LTE) to avoid corrupted files."
            }
          ]
        },
        {
          tabId: "pref-legal",
          tabBtnLabel: "Legal & Privacy Agreements",
          title: "Accessing FSI Agreements",
          lead: "You can securely read all of FSI's courier agreements offline directly inside the mobile app:",
          steps: [
            {
              number: "1",
              title: "Terms of Service",
              text: "Read the standard operating rules, compliance directives, and pay structure codes."
            },
            {
              number: "2",
              title: "Privacy Policy",
              text: "Review how FSI securely manages your personal device profiles and GPS location logs."
            },
            {
              number: "3",
              title: "Local Asset Integrity",
              text: "All terms and agreements are stored locally as text files on your phone so you can read them at any time without data usage!"
            }
          ]
        }
      ]
    },

    // 13. Change Password
    {
      id: "sec-change-password",
      category: "Security",
      title: "Change Password",
      lead: "Keep your app credentials and earnings wallet secure by updating your password regularly.",
      steps: [
        {
          number: "1",
          title: "Tap Change Password",
          text: "Open your profile screen and tap **Change Password** to open the secure input page."
        },
        {
          number: "2",
          title: "Verify Codes & Save",
          text: "Type in your **Current Password**, followed by your **New Password** and confirm it in the box below. Tap save. For your safety, the app will securely log you out and prompt you to sign in again using your new password."
        }
      ],
      screenshot: {
        label: "📸 Add Password Change Screenshot",
        dimensions: "Size: 320x640px"
      }
    },

    // 14. Other (Background Sync & Diagnostics)
    {
      id: "sec-other",
      category: "Operations",
      title: "Other (Background Sync & Diagnostics)",
      lead: "Review additional background sync details, safety mechanisms, notifications, and issue submissions:",
      tabs: [
        {
          tabId: "other-sync-details",
          tabBtnLabel: "Background Sync Details",
          title: "Understanding How Syncing Works",
          lead: "Your delivery records and photos are safely processed in the background. Here is how it works:",
          steps: [
            {
              number: "a",
              title: "Automatic 3-Minute Sync Timer",
              text: "Every <strong>3 minutes</strong> while the app is active and your phone has internet, the app automatically uploads your pending updates to the FSI system."
            },
            {
              number: "b",
              title: "Silent Automatic Uploads",
              text: "If you close the app, the phone's system will occasionally try to upload your completed deliveries in the background when connected to the internet, so you don't need to worry!"
            },
            {
              number: "c",
              title: "Photo Delivery Guarantee",
              text: "When uploading photos, the app enforces a strict safety rule: your delivery will not be marked as successfully saved on the server until your photo proofs are fully uploaded. This guarantees your payout!"
            },
            {
              number: "d",
              title: "Delivery Protection",
              text: "When downloading new deliveries, the app **never overwrites** any work you've already completed offline on your phone. Your hard work is always protected!"
            }
          ]
        },
        {
          tabId: "other-diagnostics",
          tabBtnLabel: "System Diagnostics & Safety",
          title: "Audits, Time Guards, and Bug Reports",
          lead: "Review additional system safety checklists:",
          steps: [
            {
              number: "1",
              title: "Phone Clock Safety Guard",
              text: "To ensure all deliveries have the correct timestamp, your phone's clock must match the network time. If your phone's clock is set manually to an incorrect time, the app will ask you to go to your phone settings and turn on <strong>Set time automatically</strong> before you can submit updates."
            },
            {
              number: "2",
              title: "Review Delivery History",
              text: "Go to the <strong>History</strong> tab from the bottom navigation bar to review all your completed, pending, or failed uploads. If you have pending uploads and want to send them immediately, tap the <strong>SYNC</strong> button in the header bar while connected to the internet."
            },
            {
              number: "3",
              title: "Report an Issue",
              text: "Having an issue with the app? Select <strong>Report Issue</strong> under your Profile. Describe what happened, pick how urgent it is, and submit. If you want, you can keep the <strong>Include technical logs</strong> checked, which automatically attaches a list of recent app errors to help our support team fix it faster. You will receive an issue tracking number (like <code>RPT-xxxx</code>)."
            },
            {
              number: "4",
              title: "Connection Banners",
              text: "A <strong>Red Banner</strong> will show at the top when you are offline (don't worry, you can still deliver safely offline!). A <strong>Green Banner</strong> will flash briefly when you go back online to confirm that your phone is successfully sending updates."
            }
          ],
          alerts: [
            {
              type: "info",
              text: "<strong>📡 Notifications Alert:</strong> Access the **Notifications** tab to view assignments, payout status alerts, and unread badges."
            }
          ]
        }
      ]
    }
  ]
};
