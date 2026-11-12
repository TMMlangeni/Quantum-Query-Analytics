

# Quantum Query: E-Hailing Market Analytics

This repository contains the data analytics portfolio, SQL scripts, and strategic findings detailed in the official project report, **Group 27 - Quantum Query - Final.pdf**. 

## Project Overview
Quantum Query is a data analytics consulting project commissioned by InDrive to evaluate the South African ride-hailing market, specifically analyzing competitors Uber and Bolt. The objective is to identify operational gaps in fleet quality, driver retention, and passenger satisfaction across major metropolitan areas (Johannesburg, Cape Town, Durban, Gqeberha, Potchefstroom, and Pretoria) to formulate data-driven onboarding and fleet management strategies.

## Tech Stack
* **Database:** PostgreSQL (pgAdmin)
* **Query Language:** SQL (CTEs, Window Functions, Aggregations)
* **Visualization:** Power BI
* **Data Modeling:** Relational Entity-Relationship Diagram (ERD) utilizing 7 interconnected tables

## Core Research Areas
1. **Regional Vehicle Benchmarking:** Identifying vehicle makes that consistently underperform local city baseline ratings to establish targeted, city-specific onboarding restrictions.
2. **Asset Age Thresholds:** Determining the exact vehicle age at which passenger satisfaction (driver ratings) measurably degrades to inform vehicle renewal programs.
3. **Platform Affiliation & Driver Longevity:** Comparing the operational lifespan (lifetime trips) of dual-platform drivers against platform-exclusive fleets to optimize driver acquisition.
4. **Tipping Behavior:** Analyzing whether vehicle age and ride category influence rider tipping percentages as a monetary proxy for exceptional satisfaction.
5. **Commission vs. Fleet Quality:** Investigating if platforms extracting higher driver commissions degrade overall fleet quality over time.

## Key Findings & Strategic Recommendations
* **City-Specific Vehicle Performance:** Vehicle makes perform differently depending on the region. Volkswagen and Kia fell below the city baseline in five out of seven analyzed cities. InDrive should adopt localized onboarding criteria rather than generic national policies.
* **Vehicle Age Cut-offs:** Passenger ratings remain stable for vehicles up to 8 years old, but drop sharply for vehicles aged 9+ years. A strict 8-year age cap is recommended for premium tiers.
* **Driver Longevity:** The assumption that dual-platform drivers always last longer is false. They sustain longer lifespans in Johannesburg, Cape Town, and Gqeberha, but exclusive drivers perform better in Pretoria, Durban, Vanderbijlpark, and Potchefstroom.
* **Tipping Patterns:** Newer vehicles do not reliably earn higher tips. Tip rates hover between 4.6% and 5.1% regardless of vehicle age, meaning age-based tipping incentives are ineffective for driver recruitment.
* **Commission Impact:** Uber extracts the highest commission (~25%) but yields the lowest average driver rating (4.53) compared to Bolt (~20% commission, 4.55 rating). Higher platform cuts do not correlate with better fleet quality.

## Contributors (Group 27)
* Kamogelo Langa (Group Leader)
* Thabiso Phasha
* Talani Mlangeni
* Othusitse Matlhaku
* Nokuthula Mbuyisa
* Neo Rantsieng
