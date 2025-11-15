
# Federal Job Finder

<div>
    <a href="https://www.loom.com/share/153f7a57644e4d2d9408d4cbac65d154">
    </a>
    <a href="https://www.loom.com/share/153f7a57644e4d2d9408d4cbac65d154">
      <img style="max-width:300px;" src="https://cdn.loom.com/sessions/thumbnails/153f7a57644e4d2d9408d4cbac65d154-495334420d6f08b0-full-play.gif#t=0.1">
    </a>
  </div>

## Table of Contents

1. [Overview](#Overview)
2. [Product Spec](#Product-Spec)
3. [Wireframes](#Wireframes)
4. [Schema](#Schema)

## Overview

### Description

Federal Job Finder is an iOS application that provides users with a streamlined way to search, discover, and track federal government job opportunities through the USAJobs API. The app focuses on delivering a clean, modern user experience that makes finding and applying for federal positions more accessible and efficient than the traditional USAJobs website.

### App Evaluation

- **Category:** Productivity / Career
- **Mobile:** Mobile-first design with offline capabilities, push notifications for job alerts, and location-based job search
- **Story:** Simplifies the federal job search process by providing a modern, intuitive interface to browse USAJobs opportunities
- **Market:** Job seekers interested in federal employment, government contractors, and career changers
- **Habit:** Users check daily for new job postings, set up saved searches with notifications, and track application deadlines
- **Scope:** Well-defined scope focusing on job search, favorites, saved searches, and application tracking with USAJobs API integration

## Product Spec

### 1. User Stories (Required and Optional)

**Required Must-have Stories**

* As a job seeker, I want to search for federal jobs using various filters, so that I can find positions that match my qualifications and preferences
* As a job seeker, I want to view detailed job information, so that I can understand the position requirements and application process
* As a job seeker, I want to save interesting job postings, so that I can review them later and track my application progress
* As a job seeker, I want to set up saved searches with notifications, so that I can be alerted when new positions matching my criteria are posted
* As a job seeker, I want to track application deadlines and status, so that I don't miss important dates and can manage my application pipeline

**Optional Nice-to-have Stories**

* As a job seeker, I want to access job information offline, so that I can review positions even without internet connectivity
* As a job seeker, I want the app to have an intuitive and accessible interface, so that I can efficiently navigate and use all features
* As a user, I want to receive push notifications for application deadlines and new job matches
* As a user, I want to share job postings with others via social media or messaging

### 2. Screen Archetypes

1. Job Search Screen
	* Search for federal jobs using filters (keywords, location, department, salary)
	* View search results in a list format
	* Apply filters and sorting options

2. Job Detail Screen
	* View detailed job information including requirements and application process
	* Save job to favorites
	* Navigate to USAJobs.gov to apply

3. Favorites Screen
	* View all saved favorite jobs
	* Remove jobs from favorites
	* Check job status (active/expired)

4. Saved Searches Screen
	* Create and manage saved search criteria
	* View new job matches for saved searches
	* Enable/disable notifications for searches

5. Applications Tracker Screen
	* Track application status and deadlines
	* View application timeline
	* Receive deadline reminders

### 3. Navigation

**Tab Navigation** (Tab to Screen)

* Search - Job Search Screen
* Favorites - Favorites Screen  
* Saved - Saved Searches Screen
* Applications - Applications Tracker Screen

**Flow Navigation** (Screen to Screen)

1. Job Search Screen
	* Navigate to Job Detail Screen when job is tapped
	* Navigate to Filter View for advanced search options
	* Navigate to Saved Searches to create new saved search

2. Job Detail Screen
	* Navigate back to Job Search Screen
	* Navigate to external USAJobs.gov for application
	* Navigate to Applications Tracker when marking as applied

3. Favorites Screen
	* Navigate to Job Detail Screen when favorite job is tapped
	* Navigate back to previous screen

4. Saved Searches Screen
	* Navigate to Job Search Screen with applied search criteria
	* Navigate to edit sheet for modifying saved searches

5. Applications Tracker Screen
	* Navigate to Job Detail Screen when application is tapped
	* Navigate to edit sheet for updating application status

### Digital Wireframes & Mockups

![Figma](Figma.png)

## Schema

### Core Data Entities

The app uses Core Data for local persistence with three main entities:

**Job**
| Property | Type | Description |
|----------|------|-------------|
| jobId | String | Unique identifier from USAJobs API |
| title | String | Position title |
| department | String | Government department/agency |
| location | String | Job location |
| applicationDeadline | Date | Application closing date |
| applicationUri | String | URL to apply on USAJobs.gov |
| datePosted | Date | When the job was posted |
| salaryMin | Int 32 | Minimum salary range |
| salaryMax | Int 32 | Maximum salary range |
| gradeDisplay | String | GS level or pay grade |
| isRemoteEligible | Boolean | Whether remote work is allowed |
| isFavorited | Boolean | Whether user has favorited this job |
| majorDutiesText | String | Job responsibilities |
| keyRequirementsText | String | Key qualifications needed |
| cachedAt | Date | When the job data was cached |

**SavedSearch**
| Property | Type | Description |
|----------|------|-------------|
| searchId | UUID | Unique identifier for the saved search |
| name | String | User-friendly name for the search |
| keywords | String | Search keywords |
| location | String | Location filter |
| department | String | Department filter |
| salaryMin | Int 32 | Minimum salary filter |
| salaryMax | Int 32 | Maximum salary filter |
| isNotificationEnabled | Boolean | Whether to receive notifications for new matches |
| lastChecked | Date | Last time this search was run for notifications |

**ApplicationTracking**
| Property | Type | Description |
|----------|------|-------------|
| jobId | String | Reference to the job being applied to |
| applicationDate | Date | When the application was submitted |
| status | String | Application status (e.g., "Applied", "Interview", "Offer") |
| notes | String | User notes about the application |
| reminderDate | Date | Optional reminder for follow-up |

### Models

The app uses several Swift models for handling API responses and business logic:

**API Response Models** (for USAJobs API integration)
| Model | Purpose |
|-------|---------|
| JobSearchResponse | Root response from USAJobs search endpoint |
| SearchResult | Container for search results and metadata |
| JobSearchItem | Individual job listing in search results |
| JobDescriptor | Detailed job information and requirements |
| PositionLocation | Geographic location data with coordinates |
| JobCategory | Job classification codes |
| JobGrade | Pay grade information (GS levels) |
| PositionRemuneration | Salary and compensation details |
| PositionFormattedDescription | Formatted job description sections |
| UserArea | Additional job metadata from USAJobs |
| UserAreaDetails | Detailed job attributes (duties, requirements, benefits) |
| WhoMayApply | Eligibility information |

**Search & Filter Models**
| Model | Purpose |
|-------|---------|
| SearchCriteria | Encapsulates search parameters (keywords, location, salary range, etc.) |

### Networking

**Base URL:** `https://data.usajobs.gov/api`

**Network Requests by Screen:**

- Job Search Screen
	- `GET /search` - Search for jobs with filters
	- Parameters: `Keyword`, `LocationName`, `Organization`, `SalaryBucket`, `RemoteIndicator`, `Page`, `ResultsPerPage`

- Job Detail Screen  
	- `GET /search?PositionID={jobId}` - Get specific job details
	- Parameters: `PositionID`, `Fields=Full`

- Saved Searches Screen
	- Uses same `GET /search` endpoint with saved criteria
	- Background refresh for new job notifications

- API Connection Validation
	- `GET /search?Keyword=test&ResultsPerPage=1` - Test API connectivity

## Project Structure

```
usajobs/
├── Core/
│   ├── AppConfiguration.swift       # App-wide configuration and constants
│   ├── CoreDataStack.swift         # Core Data persistence layer
│   └── FederalJobFinder.xcdatamodeld # Core Data model definitions
├── Models/
│   ├── APIResponseModels.swift     # USAJobs API response structures
│   ├── SearchCriteria.swift        # Search query model
│   ├── Job+Extensions.swift        # Core Data Job entity extensions
│   ├── SavedSearch+Extensions.swift # Core Data SavedSearch extensions
│   └── ApplicationTracking+Extensions.swift # Core Data ApplicationTracking extensions
├── ViewModels/
│   ├── JobSearchViewModel.swift    # Search screen business logic
│   ├── JobDetailViewModel.swift    # Job detail screen logic
│   ├── FavoritesViewModel.swift    # Favorites management
│   ├── SavedSearchViewModel.swift  # Saved searches management
│   └── ApplicationTrackingViewModel.swift # Application tracking logic
├── Views/
│   ├── JobSearchView.swift         # Main search interface
│   ├── JobDetailView.swift         # Job details screen
│   ├── JobRowView.swift            # Job list item component
│   ├── FavoritesView.swift         # Favorites list screen
│   ├── FavoriteJobRowView.swift    # Favorite job list item
│   ├── SavedSearchesView.swift     # Saved searches list
│   ├── SavedSearchEditSheet.swift  # Create/edit saved search
│   ├── ApplicationsView.swift      # Application tracking screen
│   ├── FilterView.swift            # Advanced search filters
│   ├── LaunchScreenView.swift      # Custom launch screen
│   ├── LoadingView.swift           # Loading state component
│   ├── ErrorView.swift             # Error state component
│   └── OfflineStatusView.swift     # Offline mode indicator
├── Services/
│   ├── USAJobsAPIService.swift     # API client for USAJobs
│   ├── NetworkConfiguration.swift  # Network layer configuration
│   ├── NetworkMonitor.swift        # Internet connectivity monitoring
│   ├── DataPersistenceService.swift # Core Data operations wrapper
│   ├── OfflineDataManager.swift    # Offline data caching and sync
│   ├── ImageCacheService.swift     # Image caching for job logos
│   └── NotificationService.swift   # Push notifications for saved searches
├── Utilities/
│   ├── Extensions.swift            # Swift/SwiftUI extensions
│   ├── ErrorHandling.swift         # Custom error types and handling
│   ├── LoadingStateManager.swift   # Loading state management
│   ├── AnalyticsManager.swift      # Usage analytics tracking
│   ├── DeepLinkManager.swift       # Deep linking support
│   ├── AppLifecycleManager.swift   # App lifecycle event handling
│   └── MemoryManager.swift         # Memory optimization utilities
├── Assets.xcassets/
│   ├── AppIcon.appiconset/         # App icon (1024x1024)
│   ├── AccentColor.colorset/       # App accent color
│   ├── LaunchScreenBackground.colorset/ # Launch screen background
│   └── LaunchScreenIcon.imageset/  # Launch screen icon
└── usajobsApp.swift                # App entry point and configuration
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Important Note:** This project is for educational purposes only. The USAJobs API is used under their educational use policy and is not intended for commercial applications. If you plan to use this code commercially, you must obtain proper authorization from USAJobs.

## Acknowledgments

- **USAJobs API** for providing federal job data for educational purposes
- **CodePath** for iOS development curriculum and guidance
- **Kiro AI** for development assistance throughout this project
- **Apple** for SwiftUI and Core Data frameworks
- The open-source community for inspiration and best practices


