# Bay Wheels Ride History Exporter

A simple browser-based tool to export your entire Lyft/Bay Wheels ride history (including Start/End stations, costs, and timestamps) into a JSON file.

Lyft/Bay Wheels currently does not offer an "Export CSV" feature on their website. This script automates the process of fetching your ride history by leveraging the existing website API while you are logged in.

## ⚠️ Disclaimer

This script is for personal archiving purposes only.

* Do not use this to scrape data that does not belong to you.
* Use responsibly. The script includes a delay to avoid overwhelming the Bay Wheels servers.
* This project is not affiliated with Lyft or Bay Wheels.

## Features

* **Full History**: Fetches rides going back 1 year (configurable).
* **Detailed Data**: Includes Start Address, End Address, Duration, Price, and Bike ID.
* **No Setup**: Runs directly in your browser console. No Python, Node.js, or API keys required.
* **JSON Export**: Automatically downloads a .json file containing your data.

## How to Use

### Step 1: Log in

Go to https://account.baywheels.com/ride-history and ensure you are logged in. You should see your recent rides listed on the page.

### Step 2: Open Developer Console

1. Right-click anywhere on the page and select **Inspect**.
2. Click on the **Console** tab in the panel that opens.

**Shortcut**: Press `F12` or `Ctrl+Shift+J` (Windows) / `Cmd+Opt+J` (Mac).

### Step 3: Run the Script

Copy and paste the code below into the Console and hit Enter.

```javascript
// CONFIGURATION
const ONE_YEAR_MS = 365 * 24 * 60 * 60 * 1000;
const CUTOFF_DATE = Date.now() - ONE_YEAR_MS; 
const DELAY_MS = 1000; // 1 second delay to be polite to the API

// GRAPHQL QUERIES
const QUERY_LIST = `query GetCurrentUserRides($startTimeMs: String, $memberId: String) {
  member(id: $memberId) {
    id
    rideHistory(startTimeMs: $startTimeMs) {
      limit
      hasMore
      rideHistoryList {
        rideId
        startTimeMs
        endTimeMs
        price { formatted }
        duration
        rideableName
      }
    }
  }
}`;

const QUERY_DETAILS = `query GetCurrentUserRideDetails($rideId: String!) {
  me {
    rideDetails(rideId: $rideId) {
      rideId
      startAddressStr
      endAddressStr
      paymentBreakdownMap {
        lineItems {
          title
          amount { formatted }
        }
      }
    }
  }
}`;

// HELPER: Wait function
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// HELPER: Generic Graphql Fetcher
async function fetchGQL(payload) {
    const response = await fetch("https://account.baywheels.com/bikesharefe-gql", {
        "headers": {
            "content-type": "application/json"
        },
        "body": JSON.stringify(payload),
        "method": "POST"
    });
    return await response.json();
}

// MAIN LOGIC
async function scrapeRideHistory() {
    console.log("🚴 Starting Ride History Scraping...");
    console.log("-----------------------------------");
    
    let allRides = [];
    let hasMore = true;
    let nextCursor = String(Date.now()); 

    // PHASE 1: Get the list of rides
    while (hasMore) {
        console.log(`Fetching page cursor: ${nextCursor} (${new Date(parseInt(nextCursor)).toLocaleString()})`);
        
        const payload = {
            operationName: "GetCurrentUserRides",
            query: QUERY_LIST,
            variables: { startTimeMs: nextCursor } 
        };

        const res = await fetchGQL(payload);
        
        if (res.errors) {
            console.error("❌ API Error:", res.errors);
            break;
        }
        if (!res.data || !res.data.member) {
            console.error("❌ Unexpected response structure:", res);
            break;
        }

        const history = res.data.member.rideHistory;
        const rides = history.rideHistoryList;

        if (!rides || rides.length === 0) {
            console.log("No more rides returned.");
            break;
        }

        allRides.push(...rides);
        console.log(`✅ Found ${rides.length} rides this page. Total: ${allRides.length}`);

        const lastRideTime = parseInt(rides[rides.length - 1].startTimeMs);
        if (lastRideTime < CUTOFF_DATE) {
            console.log("Reached one year cutoff.");
            hasMore = false;
        } else {
            hasMore = history.hasMore;
            nextCursor = rides[rides.length - 1].startTimeMs;
        }
        
        await sleep(DELAY_MS);
    }

    console.log("-----------------------------------");
    console.log(`🎉 List fetching complete. Found ${allRides.length} rides.`);
    console.log("Starting detail fetch (Addresses and Costs)...");

    // PHASE 2: Enrich with Details (Addresses)
    const detailedRides = [];
    
    for (let i = 0; i < allRides.length; i++) {
        const ride = allRides[i];
        
        if (i % 5 === 0) console.log(`Processing details: ${i} of ${allRides.length} (${Math.round((i/allRides.length)*100)}%)`);

        const payload = {
            operationName: "GetCurrentUserRideDetails",
            query: QUERY_DETAILS,
            variables: { rideId: ride.rideId }
        };

        try {
            const detailRes = await fetchGQL(payload);
            
            if(detailRes.data && detailRes.data.me && detailRes.data.me.rideDetails) {
                 const details = detailRes.data.me.rideDetails;
                 detailedRides.push({
                    ...ride,
                    startAddress: details.startAddressStr,
                    endAddress: details.endAddressStr,
                    lineItems: details.paymentBreakdownMap?.lineItems || []
                 });
            } else {
                detailedRides.push(ride); 
            }
        } catch (e) {
            console.warn(`Failed to fetch details for ${ride.rideId}`, e);
            detailedRides.push(ride);
        }

        await sleep(DELAY_MS);
    }

    // PHASE 3: Download
    console.log("💾 Scraping complete. Downloading file...");
    const blob = new Blob([JSON.stringify(detailedRides, null, 2)], {type: "application/json"});
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `baywheels_history_full_${new Date().toISOString().split('T')[0]}.json`;
    a.click();
}

scrapeRideHistory();
```

### Step 4: Wait & Save

1. The script will log its progress in the console.
2. Depending on how many rides you have, this may take a few minutes (approx. 1 second per ride).
3. Once finished, a file named `baywheels_history_full_YYYY-MM-DD.json` will automatically download to your computer.

## Converting to CSV

The output is a JSON file. If you prefer Excel/CSV:

1. Use an online converter like [convertcsv.com/json-to-csv.htm](https://www.convertcsv.com/json-to-csv.htm).
2. Upload the JSON file you just downloaded.
3. Download the resulting CSV.

## Troubleshooting

* **"id is not supported"**: This usually happens if the script tries to send a null Member ID. The current script avoids this by relying on your session cookie.
* **Script stops early**: Ensure you keep the tab open and active. Modern browsers may pause scripts in background tabs to save battery.
* **401/403 Errors**: Your session likely expired. Refresh the page, log in again, and re-run the script.
