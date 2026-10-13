import 'package:flutter/material.dart';

/// كل محتوى التطبيق بهذا الملف. عدّل هنا وأعد البناء.
class Profile {
  static const name = 'محمد الصادق';
  static const city = 'البصرة';
  static const tagline = 'نهاري بين المختبر والكاميرا';
  static const roles = [
    'مخرج',
    'كاتب سيناريو',
    'صانع محتوى',
    'مصوّر سينمائي',
    'أخصائي مختبرات طبية',
  ];
}

class Item {
  final String title;
  final String subtitle;
  final IconData icon;
  const Item(this.title, this.subtitle, this.icon);
}

class Group {
  final String title;
  final IconData icon;
  final List<Item> items;
  const Group(this.title, this.icon, this.items);
}

const films = [
  Item('أن تكون عراقيًا', 'كتابة وإخراج', Icons.movie_creation_outlined),
  Item('برزخ', 'فيلم نفسي قصير — كتابة وإخراج', Icons.psychology_outlined),
];

const campaigns = [
  Item('بريفيه', 'حملات وفيديوات', Icons.local_cafe_outlined),
  Item('عيادة ريڤال', 'حملات وفيديوات', Icons.medical_services_outlined),
  Item('Ngenco', 'حملات وفيديوات', Icons.business_outlined),
  Item('eStore', 'حملات وفيديوات', Icons.shopping_bag_outlined),
];

const currentWork = [
  Item('محتوى عيادة ريڤال', 'شغّال عليه هسه', Icons.videocam_outlined),
];

const gear = [
  Group('الكاميرات والعدسات', Icons.camera_alt_outlined, [
    Item('Sony FX3', 'مع 24-70mm GM و 50mm f/1.4 GM', Icons.camera_outlined),
    Item(
      'Canon C70',
      'مع Sirui Venus أنامورفيك 35mm و 75mm (1.6x)',
      Icons.camera_outlined,
    ),
  ]),
  Group('التثبيت والمراقبة', Icons.control_camera_outlined, [
    Item('DJI Ronin RS 4 Pro', 'جيمبل', Icons.threed_rotation_outlined),
    Item('Atomos Ninja V', 'شاشة ومسجّل خارجي', Icons.monitor_outlined),
  ]),
  Group('الإضاءة', Icons.light_outlined, [
    Item('Sirui C300B', '', Icons.wb_incandescent_outlined),
    Item('Amaran 360c', 'RGB', Icons.wb_incandescent_outlined),
    Item('Amaran 120c', 'RGB', Icons.wb_incandescent_outlined),
  ]),
  Group('الصوت', Icons.mic_none_outlined, [
    Item('Zoom H6', 'مسجّل صوت', Icons.graphic_eq),
    Item('Lark Max 2', 'مايكات لاسلكية', Icons.mic_external_on_outlined),
  ]),
  Group('المونتاج', Icons.computer_outlined, [
    Item('MacBook Pro M4 Max', '', Icons.laptop_mac_outlined),
    Item('DaVinci Resolve Studio', 'مونتاج وكلر', Icons.color_lens_outlined),
  ]),
];

const myApps = [
  Item(
    'CineSet',
    'تطبيق إدارة الإنتاج — Swift / SwiftUI',
    Icons.movie_filter_outlined,
  ),
  Item(
    'Scripo AI',
    'أفكار تطبيقات بالذكاء الاصطناعي',
    Icons.auto_awesome_outlined,
  ),
];

const life = [
  Group('السيارة', Icons.directions_car_outlined, [
    Item('شيفروليه كمارو 2023', 'حمرة — 1LT تيربو', Icons.directions_car),
    Item('قبلها', 'توسان وسنترا', Icons.history),
  ]),
  Group('الأجهزة', Icons.devices_other_outlined, [
    Item('Realme GT 8 Pro', '', Icons.phone_android),
    Item('iPhone 15 Pro Max', '', Icons.phone_iphone),
    Item('Nintendo Switch OLED', '', Icons.sports_esports_outlined),
  ]),
  Group('الاهتمامات', Icons.favorite_border, [
    Item(
      'الذكاء الاصطناعي محلياً',
      'أشغّل الأدوات على أجهزة أبل',
      Icons.memory_outlined,
    ),
    Item('السفر', 'اكتشاف المدن والطبيعة', Icons.flight_takeoff),
    Item('اللعب ويه الربع', 'مثلاً بكافيه بريفيه', Icons.groups_outlined),
  ]),
];

const family = [
  Item('زهرتي', 'زوجتي', Icons.favorite),
  Item('زيودي', 'ابني', Icons.child_care),
  Item('ليلى', 'بنتي الصغيرة', Icons.child_friendly),
];

class Salon {
  static const name = 'برتي ليدي';
  static const kind = 'مركز رشاقة وصالون';
  static const address = 'شط العرب — مقابل المركز الصحي، البصرة';
  static const openHour = 9;
  static const closeHour = 21;

  /// اكتب الرقم بالصيغة الدولية، مثلاً 9647701234567. إذا فارغ تختفي أزرار الاتصال.
  static const phone = '';
  static const instagram = '';
  static const mapsQuery = 'برتي ليدي شط العرب البصرة';

  static bool isOpen(DateTime now) =>
      now.hour >= openHour && now.hour < closeHour;
}
