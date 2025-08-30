# Sri Lankan Tax Application - Frontend

This is the frontend for the Sri Lankan Tax Calculation Application, built with [Next.js 15](https://nextjs.org) and [React 19](https://react.dev).

## 🚀 Getting Started

### Prerequisites
- Node.js (v18 or higher)
- npm or yarn

### Installation

1. **Install dependencies**:
```bash
npm install
```

2. **Set up environment variables**:
```bash
cp .env.example .env.local
```
Edit `.env.local` with your configuration:
```env
NEXT_PUBLIC_API_URL=http://localhost:5000
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

3. **Run the development server**:
```bash
npm run dev
```
*Note: Uses Turbopack for faster development builds*

4. **Open your browser**:
Visit [http://localhost:3000](http://localhost:3000) to see the application.

## 🛠️ Technology Stack

- **Next.js 15** - React framework with App Router
- **React 19** - Latest React version  
- **Tailwind CSS v4** - Utility-first CSS framework
- **TypeScript** - Type safety (configured)

## 📁 Project Structure

```
frontend/
├── app/                    # Next.js App Router
│   ├── admin/             # Admin dashboard pages
│   ├── api/               # API routes
│   ├── chat/              # Chat interface
│   ├── forms/             # Dynamic tax forms
│   └── upload/            # Document upload
├── components/            # React components
│   ├── ChatInterface.jsx # AI chat widget
│   ├── FormRenderer.jsx  # Dynamic form renderer
│   └── ...
├── lib/                   # Utility functions
└── public/               # Static assets
```

## 🧪 Available Scripts

- `npm run dev` - Start development server with Turbopack
- `npm run build` - Build for production
- `npm run start` - Start production server

## 🎨 Features

- **Dynamic Tax Forms** - Generated from AI-extracted rules
- **Real-time Chat** - AI-powered tax assistant
- **Responsive Design** - Mobile-first approach
- **Fast Development** - Turbopack for instant updates
- **Modern Typography** - Geist font family optimization

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a modern font family for better readability.


