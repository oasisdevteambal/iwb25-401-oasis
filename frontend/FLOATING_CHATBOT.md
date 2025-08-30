# Floating Chatbot Feature

## Overview
Added a floating chatbot widget that appears on all pages except admin pages and the dedicated chat page. The chatbot provides the same functionality as the main chat interface but in a compact, floating format.

## Features

### 🎯 Smart Positioning
- Appears on all pages except:
  - Admin dashboard (`/admin/*`)
  - Dedicated chat page (`/chat`)

### 🎨 Animations
- **Entrance**: Smooth scale and fade-in animation
- **Bounce effect**: Button has a subtle bounce when appearing
- **Pulse animation**: Continuous subtle pulse on the floating button
- **Slide animations**: Chat messages slide up smoothly
- **Minimize/Maximize**: Smooth transitions with scale and opacity

### 💬 Interactive Elements
- **Floating Button**: 
  - Blue gradient background
  - Chat icon that transforms to X when open
  - Red notification dot when new messages arrive while closed
  - Hover effects with scale transformation

- **Chat Widget**:
  - Compact 384px width
  - Fixed 500px max height
  - Responsive design
  - Same functionality as main chat interface

### 🔧 Technical Implementation

#### Components Created
1. `FloatingChatbot.jsx` - Main floating chatbot component
2. `ConditionalFloatingChatbot.jsx` - Route-aware wrapper component

#### Components Modified
1. `ChatMessage.jsx` - Added compact mode support
2. `ChatInput.jsx` - Added compact mode support  
3. `SchemaSelector_fixed.jsx` - Added compact mode support
4. `layout.js` - Integrated floating chatbot
5. `globals.css` - Added custom animations

#### Key Features
- **Compact Mode**: All child components support a `compact` prop for smaller sizing
- **Route Detection**: Uses Next.js `usePathname` to conditionally render
- **State Management**: Maintains conversation state across page navigation
- **Responsive Design**: Adapts to different screen sizes

#### Animations Added
```css
@keyframes bounceIn { /* Button entrance */ }
@keyframes pulse { /* Continuous button pulse */ }
@keyframes slideUp { /* Message animations */ }
@keyframes slideDown { /* Dropdown animations */ }
```

## Usage
The floating chatbot automatically appears on all applicable pages. Users can:
1. Click the floating button to open/close
2. Use all chat features in compact mode
3. Receive notifications when closed
4. Navigate pages while maintaining chat state

## File Structure
```
components/
├── FloatingChatbot.jsx           # Main floating chatbot
├── ConditionalFloatingChatbot.jsx # Route-aware wrapper
├── ChatMessage.jsx               # Updated with compact mode
├── ChatInput.jsx                 # Updated with compact mode
├── SchemaSelector_fixed.jsx      # Fixed version with compact mode
└── [other existing components]

app/
├── layout.js                     # Integrated floating chatbot
└── globals.css                   # Added animations
```

## Browser Compatibility
- Modern browsers with CSS transforms support
- Fallback for reduced motion preferences
- Responsive breakpoints for mobile devices
