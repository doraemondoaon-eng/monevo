import type { ICON_KEYS } from '../../common/schemas.js';

type Seed = { name: string; icon: (typeof ICON_KEYS)[number]; color: string };

/**
 * Section 6.6 Default Expense & Income Categories:
 * Includes all required Thai categories:
 * เงินเดือน, รายได้เสริม, อาหาร, เดินทาง, ที่พัก, ค่าน้ำ, ค่าไฟ, ช้อปปิ้ง, สุขภาพ, ความบันเทิง
 */
export const DEFAULT_EXPENSE_CATEGORIES: Seed[] = [
  { name: 'อาหาร', icon: 'restaurant', color: '#F97316' },
  { name: 'เดินทาง', icon: 'directions_car', color: '#0EA5E9' },
  { name: 'ที่พัก', icon: 'home', color: '#8B5CF6' },
  { name: 'ค่าน้ำ', icon: 'water_drop', color: '#38BDF8' },
  { name: 'ค่าไฟ', icon: 'bolt', color: '#EAB308' },
  { name: 'ช้อปปิ้ง', icon: 'shopping_bag', color: '#EC4899' },
  { name: 'สุขภาพ', icon: 'medical_services', color: '#EF4444' },
  { name: 'ความบันเทิง', icon: 'movie', color: '#A855F7' },
  { name: 'อินเทอร์เน็ตและโทรศัพท์', icon: 'wifi', color: '#06B6D4' },
  { name: 'การศึกษา', icon: 'school', color: '#3B82F6' },
  { name: 'ประกันภัย', icon: 'shield', color: '#14B8A6' },
  { name: 'อื่น ๆ', icon: 'more_horiz', color: '#64748B' },
];

export const DEFAULT_INCOME_CATEGORIES: Seed[] = [
  { name: 'เงินเดือน', icon: 'work', color: '#10B981' },
  { name: 'รายได้เสริม', icon: 'store', color: '#6366F1' },
  { name: 'โบนัส', icon: 'star', color: '#F59E0B' },
  { name: 'การลงทุน', icon: 'trending_up', color: '#22C55E' },
  { name: 'ดอกเบี้ย', icon: 'percent', color: '#0EA5E9' },
  { name: 'อื่น ๆ', icon: 'more_horiz', color: '#64748B' },
];
