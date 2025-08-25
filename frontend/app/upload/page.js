import { redirect } from 'next/navigation';

export default function UploadPage() {
  // Upload is restricted to Admin Dashboard
  redirect('/admin');
}
