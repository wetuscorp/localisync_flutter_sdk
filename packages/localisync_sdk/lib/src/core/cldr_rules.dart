// Generated from Unicode CLDR JSON 48.2.1. Run tool/generate_cldr.py.
// See NOTICE and licenses/Unicode-LICENSE.txt.
part of 'plural.dart';

final _cardinalRules = <String, String Function(PluralOperands)>{
  'af': _cardinal0,
  'an': _cardinal0,
  'asa': _cardinal0,
  'az': _cardinal0,
  'bal': _cardinal0,
  'bem': _cardinal0,
  'bez': _cardinal0,
  'bg': _cardinal0,
  'brx': _cardinal0,
  'ce': _cardinal0,
  'cgg': _cardinal0,
  'chr': _cardinal0,
  'ckb': _cardinal0,
  'dv': _cardinal0,
  'ee': _cardinal0,
  'el': _cardinal0,
  'eo': _cardinal0,
  'eu': _cardinal0,
  'fo': _cardinal0,
  'fur': _cardinal0,
  'gsw': _cardinal0,
  'ha': _cardinal0,
  'haw': _cardinal0,
  'hu': _cardinal0,
  'jgo': _cardinal0,
  'jmc': _cardinal0,
  'ka': _cardinal0,
  'kaj': _cardinal0,
  'kcg': _cardinal0,
  'kk': _cardinal0,
  'kkj': _cardinal0,
  'kl': _cardinal0,
  'ks': _cardinal0,
  'ksb': _cardinal0,
  'ku': _cardinal0,
  'ky': _cardinal0,
  'lb': _cardinal0,
  'lg': _cardinal0,
  'mas': _cardinal0,
  'mgo': _cardinal0,
  'ml': _cardinal0,
  'mn': _cardinal0,
  'mr': _cardinal0,
  'nah': _cardinal0,
  'nb': _cardinal0,
  'nd': _cardinal0,
  'ne': _cardinal0,
  'nn': _cardinal0,
  'nnh': _cardinal0,
  'no': _cardinal0,
  'nr': _cardinal0,
  'ny': _cardinal0,
  'nyn': _cardinal0,
  'om': _cardinal0,
  'or': _cardinal0,
  'os': _cardinal0,
  'pap': _cardinal0,
  'ps': _cardinal0,
  'rm': _cardinal0,
  'rof': _cardinal0,
  'rwk': _cardinal0,
  'saq': _cardinal0,
  'sd': _cardinal0,
  'sdh': _cardinal0,
  'seh': _cardinal0,
  'sn': _cardinal0,
  'so': _cardinal0,
  'sq': _cardinal0,
  'ss': _cardinal0,
  'ssy': _cardinal0,
  'st': _cardinal0,
  'syr': _cardinal0,
  'ta': _cardinal0,
  'te': _cardinal0,
  'teo': _cardinal0,
  'tig': _cardinal0,
  'tk': _cardinal0,
  'tn': _cardinal0,
  'tr': _cardinal0,
  'ts': _cardinal0,
  'ug': _cardinal0,
  'uz': _cardinal0,
  've': _cardinal0,
  'vo': _cardinal0,
  'vun': _cardinal0,
  'wae': _cardinal0,
  'xh': _cardinal0,
  'xog': _cardinal0,
  'ak': _cardinal1,
  'bho': _cardinal1,
  'csw': _cardinal1,
  'guw': _cardinal1,
  'ln': _cardinal1,
  'mg': _cardinal1,
  'nso': _cardinal1,
  'pa': _cardinal1,
  'ti': _cardinal1,
  'wa': _cardinal1,
  'am': _cardinal2,
  'as': _cardinal2,
  'bn': _cardinal2,
  'doi': _cardinal2,
  'fa': _cardinal2,
  'gu': _cardinal2,
  'hi': _cardinal2,
  'kn': _cardinal2,
  'kok': _cardinal2,
  'kok-Latn': _cardinal2,
  'pcm': _cardinal2,
  'zu': _cardinal2,
  'ar': _cardinal3,
  'ars': _cardinal3,
  'ast': _cardinal4,
  'de': _cardinal4,
  'en': _cardinal4,
  'et': _cardinal4,
  'fi': _cardinal4,
  'fy': _cardinal4,
  'gl': _cardinal4,
  'ia': _cardinal4,
  'ie': _cardinal4,
  'io': _cardinal4,
  'lij': _cardinal4,
  'nl': _cardinal4,
  'sc': _cardinal4,
  'sv': _cardinal4,
  'sw': _cardinal4,
  'ur': _cardinal4,
  'yi': _cardinal4,
  'be': _cardinal5,
  'blo': _cardinal6,
  'cv': _cardinal6,
  'ksh': _cardinal6,
  'bm': _cardinal7,
  'bo': _cardinal7,
  'dz': _cardinal7,
  'hnj': _cardinal7,
  'id': _cardinal7,
  'ig': _cardinal7,
  'ii': _cardinal7,
  'ja': _cardinal7,
  'jbo': _cardinal7,
  'jv': _cardinal7,
  'jw': _cardinal7,
  'kde': _cardinal7,
  'kea': _cardinal7,
  'km': _cardinal7,
  'ko': _cardinal7,
  'lkt': _cardinal7,
  'lo': _cardinal7,
  'ms': _cardinal7,
  'my': _cardinal7,
  'nqo': _cardinal7,
  'osa': _cardinal7,
  'sah': _cardinal7,
  'ses': _cardinal7,
  'sg': _cardinal7,
  'su': _cardinal7,
  'th': _cardinal7,
  'to': _cardinal7,
  'tpi': _cardinal7,
  'und': _cardinal7,
  'vi': _cardinal7,
  'wo': _cardinal7,
  'yo': _cardinal7,
  'yue': _cardinal7,
  'zh': _cardinal7,
  'br': _cardinal8,
  'bs': _cardinal9,
  'hr': _cardinal9,
  'sh': _cardinal9,
  'sr': _cardinal9,
  'ca': _cardinal10,
  'it': _cardinal10,
  'lld': _cardinal10,
  'pt-PT': _cardinal10,
  'scn': _cardinal10,
  'vec': _cardinal10,
  'ceb': _cardinal11,
  'fil': _cardinal11,
  'tl': _cardinal11,
  'cs': _cardinal12,
  'sk': _cardinal12,
  'cy': _cardinal13,
  'da': _cardinal14,
  'dsb': _cardinal15,
  'hsb': _cardinal15,
  'es': _cardinal16,
  'ff': _cardinal17,
  'hy': _cardinal17,
  'kab': _cardinal17,
  'fr': _cardinal18,
  'ga': _cardinal19,
  'gd': _cardinal20,
  'gv': _cardinal21,
  'he': _cardinal22,
  'is': _cardinal23,
  'iu': _cardinal24,
  'naq': _cardinal24,
  'sat': _cardinal24,
  'se': _cardinal24,
  'sma': _cardinal24,
  'smi': _cardinal24,
  'smj': _cardinal24,
  'smn': _cardinal24,
  'sms': _cardinal24,
  'kw': _cardinal25,
  'lag': _cardinal26,
  'lt': _cardinal27,
  'lv': _cardinal28,
  'prg': _cardinal28,
  'mk': _cardinal29,
  'mo': _cardinal30,
  'ro': _cardinal30,
  'mt': _cardinal31,
  'pl': _cardinal32,
  'pt': _cardinal33,
  'ru': _cardinal34,
  'uk': _cardinal34,
  'sgs': _cardinal35,
  'shi': _cardinal36,
  'si': _cardinal37,
  'sl': _cardinal38,
  'tzm': _cardinal39,
};
String _cardinal0(PluralOperands o) {
  if (((o.n == 1))) return 'one';
  return 'other';
}

String _cardinal1(PluralOperands o) {
  if (((o.n == o.n.truncateToDouble() && ((o.n >= 0 && o.n <= 1)))))
    return 'one';
  return 'other';
}

String _cardinal2(PluralOperands o) {
  if (((o.i == 0)) || ((o.n == 1))) return 'one';
  return 'other';
}

String _cardinal3(PluralOperands o) {
  if (((o.n == 0))) return 'zero';
  if (((o.n == 1))) return 'one';
  if (((o.n == 2))) return 'two';
  if ((((o.n % 100) == (o.n % 100).truncateToDouble() &&
      (((o.n % 100) >= 3 && (o.n % 100) <= 10)))))
    return 'few';
  if ((((o.n % 100) == (o.n % 100).truncateToDouble() &&
      (((o.n % 100) >= 11 && (o.n % 100) <= 99)))))
    return 'many';
  return 'other';
}

String _cardinal4(PluralOperands o) {
  if (((o.i == 1) && (o.v == 0))) return 'one';
  return 'other';
}

String _cardinal5(PluralOperands o) {
  if ((((o.n % 10) == 1) && !((o.n % 100) == 11))) return 'one';
  if ((((o.n % 10) == (o.n % 10).truncateToDouble() &&
          (((o.n % 10) >= 2 && (o.n % 10) <= 4))) &&
      !((o.n % 100) == (o.n % 100).truncateToDouble() &&
          (((o.n % 100) >= 12 && (o.n % 100) <= 14)))))
    return 'few';
  if ((((o.n % 10) == 0)) ||
      (((o.n % 10) == (o.n % 10).truncateToDouble() &&
          (((o.n % 10) >= 5 && (o.n % 10) <= 9)))) ||
      (((o.n % 100) == (o.n % 100).truncateToDouble() &&
          (((o.n % 100) >= 11 && (o.n % 100) <= 14)))))
    return 'many';
  return 'other';
}

String _cardinal6(PluralOperands o) {
  if (((o.n == 0))) return 'zero';
  if (((o.n == 1))) return 'one';
  return 'other';
}

String _cardinal7(PluralOperands o) {
  return 'other';
}

String _cardinal8(PluralOperands o) {
  if ((((o.n % 10) == 1) &&
      !((o.n % 100) == 11 || (o.n % 100) == 71 || (o.n % 100) == 91)))
    return 'one';
  if ((((o.n % 10) == 2) &&
      !((o.n % 100) == 12 || (o.n % 100) == 72 || (o.n % 100) == 92)))
    return 'two';
  if ((((o.n % 10) == (o.n % 10).truncateToDouble() &&
          (((o.n % 10) >= 3 && (o.n % 10) <= 4) || (o.n % 10) == 9)) &&
      !((o.n % 100) == (o.n % 100).truncateToDouble() &&
          (((o.n % 100) >= 10 && (o.n % 100) <= 19) ||
              ((o.n % 100) >= 70 && (o.n % 100) <= 79) ||
              ((o.n % 100) >= 90 && (o.n % 100) <= 99)))))
    return 'few';
  if ((!(o.n == 0) && ((o.n % 1000000) == 0))) return 'many';
  return 'other';
}

String _cardinal9(PluralOperands o) {
  if (((o.v == 0) && ((o.i % 10) == 1) && !((o.i % 100) == 11)) ||
      (((o.f % 10) == 1) && !((o.f % 100) == 11)))
    return 'one';
  if (((o.v == 0) &&
          ((o.i % 10) == (o.i % 10).truncateToDouble() &&
              (((o.i % 10) >= 2 && (o.i % 10) <= 4))) &&
          !((o.i % 100) == (o.i % 100).truncateToDouble() &&
              (((o.i % 100) >= 12 && (o.i % 100) <= 14)))) ||
      (((o.f % 10) == (o.f % 10).truncateToDouble() &&
              (((o.f % 10) >= 2 && (o.f % 10) <= 4))) &&
          !((o.f % 100) == (o.f % 100).truncateToDouble() &&
              (((o.f % 100) >= 12 && (o.f % 100) <= 14)))))
    return 'few';
  return 'other';
}

String _cardinal10(PluralOperands o) {
  if (((o.i == 1) && (o.v == 0))) return 'one';
  if (((o.e == 0) && !(o.i == 0) && ((o.i % 1000000) == 0) && (o.v == 0)) ||
      (!(o.e == o.e.truncateToDouble() && ((o.e >= 0 && o.e <= 5)))))
    return 'many';
  return 'other';
}

String _cardinal11(PluralOperands o) {
  if (((o.v == 0) && (o.i == 1 || o.i == 2 || o.i == 3)) ||
      ((o.v == 0) &&
          !((o.i % 10) == 4 || (o.i % 10) == 6 || (o.i % 10) == 9)) ||
      (!(o.v == 0) && !((o.f % 10) == 4 || (o.f % 10) == 6 || (o.f % 10) == 9)))
    return 'one';
  return 'other';
}

String _cardinal12(PluralOperands o) {
  if (((o.i == 1) && (o.v == 0))) return 'one';
  if (((o.i == o.i.truncateToDouble() && ((o.i >= 2 && o.i <= 4))) &&
      (o.v == 0)))
    return 'few';
  if ((!(o.v == 0))) return 'many';
  return 'other';
}

String _cardinal13(PluralOperands o) {
  if (((o.n == 0))) return 'zero';
  if (((o.n == 1))) return 'one';
  if (((o.n == 2))) return 'two';
  if (((o.n == 3))) return 'few';
  if (((o.n == 6))) return 'many';
  return 'other';
}

String _cardinal14(PluralOperands o) {
  if (((o.n == 1)) || (!(o.t == 0) && (o.i == 0 || o.i == 1))) return 'one';
  return 'other';
}

String _cardinal15(PluralOperands o) {
  if (((o.v == 0) && ((o.i % 100) == 1)) || (((o.f % 100) == 1))) return 'one';
  if (((o.v == 0) && ((o.i % 100) == 2)) || (((o.f % 100) == 2))) return 'two';
  if (((o.v == 0) &&
          ((o.i % 100) == (o.i % 100).truncateToDouble() &&
              (((o.i % 100) >= 3 && (o.i % 100) <= 4)))) ||
      (((o.f % 100) == (o.f % 100).truncateToDouble() &&
          (((o.f % 100) >= 3 && (o.f % 100) <= 4)))))
    return 'few';
  return 'other';
}

String _cardinal16(PluralOperands o) {
  if (((o.n == 1))) return 'one';
  if (((o.e == 0) && !(o.i == 0) && ((o.i % 1000000) == 0) && (o.v == 0)) ||
      (!(o.e == o.e.truncateToDouble() && ((o.e >= 0 && o.e <= 5)))))
    return 'many';
  return 'other';
}

String _cardinal17(PluralOperands o) {
  if (((o.i == 0 || o.i == 1))) return 'one';
  return 'other';
}

String _cardinal18(PluralOperands o) {
  if (((o.i == 0 || o.i == 1))) return 'one';
  if (((o.e == 0) && !(o.i == 0) && ((o.i % 1000000) == 0) && (o.v == 0)) ||
      (!(o.e == o.e.truncateToDouble() && ((o.e >= 0 && o.e <= 5)))))
    return 'many';
  return 'other';
}

String _cardinal19(PluralOperands o) {
  if (((o.n == 1))) return 'one';
  if (((o.n == 2))) return 'two';
  if (((o.n == o.n.truncateToDouble() && ((o.n >= 3 && o.n <= 6)))))
    return 'few';
  if (((o.n == o.n.truncateToDouble() && ((o.n >= 7 && o.n <= 10)))))
    return 'many';
  return 'other';
}

String _cardinal20(PluralOperands o) {
  if (((o.n == 1 || o.n == 11))) return 'one';
  if (((o.n == 2 || o.n == 12))) return 'two';
  if (((o.n == o.n.truncateToDouble() &&
      ((o.n >= 3 && o.n <= 10) || (o.n >= 13 && o.n <= 19)))))
    return 'few';
  return 'other';
}

String _cardinal21(PluralOperands o) {
  if (((o.v == 0) && ((o.i % 10) == 1))) return 'one';
  if (((o.v == 0) && ((o.i % 10) == 2))) return 'two';
  if (((o.v == 0) &&
      ((o.i % 100) == 0 ||
          (o.i % 100) == 20 ||
          (o.i % 100) == 40 ||
          (o.i % 100) == 60 ||
          (o.i % 100) == 80)))
    return 'few';
  if ((!(o.v == 0))) return 'many';
  return 'other';
}

String _cardinal22(PluralOperands o) {
  if (((o.i == 1) && (o.v == 0)) || ((o.i == 0) && !(o.v == 0))) return 'one';
  if (((o.i == 2) && (o.v == 0))) return 'two';
  return 'other';
}

String _cardinal23(PluralOperands o) {
  if (((o.t == 0) && ((o.i % 10) == 1) && !((o.i % 100) == 11)) ||
      (((o.t % 10) == 1) && !((o.t % 100) == 11)))
    return 'one';
  return 'other';
}

String _cardinal24(PluralOperands o) {
  if (((o.n == 1))) return 'one';
  if (((o.n == 2))) return 'two';
  return 'other';
}

String _cardinal25(PluralOperands o) {
  if (((o.n == 0))) return 'zero';
  if (((o.n == 1))) return 'one';
  if ((((o.n % 100) == 2 ||
          (o.n % 100) == 22 ||
          (o.n % 100) == 42 ||
          (o.n % 100) == 62 ||
          (o.n % 100) == 82)) ||
      (((o.n % 1000) == 0) &&
          ((o.n % 100000) == (o.n % 100000).truncateToDouble() &&
              (((o.n % 100000) >= 1000 && (o.n % 100000) <= 20000) ||
                  (o.n % 100000) == 40000 ||
                  (o.n % 100000) == 60000 ||
                  (o.n % 100000) == 80000))) ||
      (!(o.n == 0) && ((o.n % 1000000) == 100000)))
    return 'two';
  if ((((o.n % 100) == 3 ||
      (o.n % 100) == 23 ||
      (o.n % 100) == 43 ||
      (o.n % 100) == 63 ||
      (o.n % 100) == 83)))
    return 'few';
  if ((!(o.n == 1) &&
      ((o.n % 100) == 1 ||
          (o.n % 100) == 21 ||
          (o.n % 100) == 41 ||
          (o.n % 100) == 61 ||
          (o.n % 100) == 81)))
    return 'many';
  return 'other';
}

String _cardinal26(PluralOperands o) {
  if (((o.n == 0))) return 'zero';
  if (((o.i == 0 || o.i == 1) && !(o.n == 0))) return 'one';
  return 'other';
}

String _cardinal27(PluralOperands o) {
  if ((((o.n % 10) == 1) &&
      !((o.n % 100) == (o.n % 100).truncateToDouble() &&
          (((o.n % 100) >= 11 && (o.n % 100) <= 19)))))
    return 'one';
  if ((((o.n % 10) == (o.n % 10).truncateToDouble() &&
          (((o.n % 10) >= 2 && (o.n % 10) <= 9))) &&
      !((o.n % 100) == (o.n % 100).truncateToDouble() &&
          (((o.n % 100) >= 11 && (o.n % 100) <= 19)))))
    return 'few';
  if ((!(o.f == 0))) return 'many';
  return 'other';
}

String _cardinal28(PluralOperands o) {
  if ((((o.n % 10) == 0)) ||
      (((o.n % 100) == (o.n % 100).truncateToDouble() &&
          (((o.n % 100) >= 11 && (o.n % 100) <= 19)))) ||
      ((o.v == 2) &&
          ((o.f % 100) == (o.f % 100).truncateToDouble() &&
              (((o.f % 100) >= 11 && (o.f % 100) <= 19)))))
    return 'zero';
  if ((((o.n % 10) == 1) && !((o.n % 100) == 11)) ||
      ((o.v == 2) && ((o.f % 10) == 1) && !((o.f % 100) == 11)) ||
      (!(o.v == 2) && ((o.f % 10) == 1)))
    return 'one';
  return 'other';
}

String _cardinal29(PluralOperands o) {
  if (((o.v == 0) && ((o.i % 10) == 1) && !((o.i % 100) == 11)) ||
      (((o.f % 10) == 1) && !((o.f % 100) == 11)))
    return 'one';
  return 'other';
}

String _cardinal30(PluralOperands o) {
  if (((o.i == 1) && (o.v == 0))) return 'one';
  if ((!(o.v == 0)) ||
      ((o.n == 0)) ||
      (!(o.n == 1) &&
          ((o.n % 100) == (o.n % 100).truncateToDouble() &&
              (((o.n % 100) >= 1 && (o.n % 100) <= 19)))))
    return 'few';
  return 'other';
}

String _cardinal31(PluralOperands o) {
  if (((o.n == 1))) return 'one';
  if (((o.n == 2))) return 'two';
  if (((o.n == 0)) ||
      (((o.n % 100) == (o.n % 100).truncateToDouble() &&
          (((o.n % 100) >= 3 && (o.n % 100) <= 10)))))
    return 'few';
  if ((((o.n % 100) == (o.n % 100).truncateToDouble() &&
      (((o.n % 100) >= 11 && (o.n % 100) <= 19)))))
    return 'many';
  return 'other';
}

String _cardinal32(PluralOperands o) {
  if (((o.i == 1) && (o.v == 0))) return 'one';
  if (((o.v == 0) &&
      ((o.i % 10) == (o.i % 10).truncateToDouble() &&
          (((o.i % 10) >= 2 && (o.i % 10) <= 4))) &&
      !((o.i % 100) == (o.i % 100).truncateToDouble() &&
          (((o.i % 100) >= 12 && (o.i % 100) <= 14)))))
    return 'few';
  if (((o.v == 0) &&
          !(o.i == 1) &&
          ((o.i % 10) == (o.i % 10).truncateToDouble() &&
              (((o.i % 10) >= 0 && (o.i % 10) <= 1)))) ||
      ((o.v == 0) &&
          ((o.i % 10) == (o.i % 10).truncateToDouble() &&
              (((o.i % 10) >= 5 && (o.i % 10) <= 9)))) ||
      ((o.v == 0) &&
          ((o.i % 100) == (o.i % 100).truncateToDouble() &&
              (((o.i % 100) >= 12 && (o.i % 100) <= 14)))))
    return 'many';
  return 'other';
}

String _cardinal33(PluralOperands o) {
  if (((o.i == o.i.truncateToDouble() && ((o.i >= 0 && o.i <= 1)))))
    return 'one';
  if (((o.e == 0) && !(o.i == 0) && ((o.i % 1000000) == 0) && (o.v == 0)) ||
      (!(o.e == o.e.truncateToDouble() && ((o.e >= 0 && o.e <= 5)))))
    return 'many';
  return 'other';
}

String _cardinal34(PluralOperands o) {
  if (((o.v == 0) && ((o.i % 10) == 1) && !((o.i % 100) == 11))) return 'one';
  if (((o.v == 0) &&
      ((o.i % 10) == (o.i % 10).truncateToDouble() &&
          (((o.i % 10) >= 2 && (o.i % 10) <= 4))) &&
      !((o.i % 100) == (o.i % 100).truncateToDouble() &&
          (((o.i % 100) >= 12 && (o.i % 100) <= 14)))))
    return 'few';
  if (((o.v == 0) && ((o.i % 10) == 0)) ||
      ((o.v == 0) &&
          ((o.i % 10) == (o.i % 10).truncateToDouble() &&
              (((o.i % 10) >= 5 && (o.i % 10) <= 9)))) ||
      ((o.v == 0) &&
          ((o.i % 100) == (o.i % 100).truncateToDouble() &&
              (((o.i % 100) >= 11 && (o.i % 100) <= 14)))))
    return 'many';
  return 'other';
}

String _cardinal35(PluralOperands o) {
  if ((((o.n % 10) == 1) && !((o.n % 100) == 11))) return 'one';
  if (((o.n == 2))) return 'two';
  if ((!(o.n == 2) &&
      ((o.n % 10) == (o.n % 10).truncateToDouble() &&
          (((o.n % 10) >= 2 && (o.n % 10) <= 9))) &&
      !((o.n % 100) == (o.n % 100).truncateToDouble() &&
          (((o.n % 100) >= 11 && (o.n % 100) <= 19)))))
    return 'few';
  if ((!(o.f == 0))) return 'many';
  return 'other';
}

String _cardinal36(PluralOperands o) {
  if (((o.i == 0)) || ((o.n == 1))) return 'one';
  if (((o.n == o.n.truncateToDouble() && ((o.n >= 2 && o.n <= 10)))))
    return 'few';
  return 'other';
}

String _cardinal37(PluralOperands o) {
  if (((o.n == 0 || o.n == 1)) || ((o.i == 0) && (o.f == 1))) return 'one';
  return 'other';
}

String _cardinal38(PluralOperands o) {
  if (((o.v == 0) && ((o.i % 100) == 1))) return 'one';
  if (((o.v == 0) && ((o.i % 100) == 2))) return 'two';
  if (((o.v == 0) &&
          ((o.i % 100) == (o.i % 100).truncateToDouble() &&
              (((o.i % 100) >= 3 && (o.i % 100) <= 4)))) ||
      (!(o.v == 0)))
    return 'few';
  return 'other';
}

String _cardinal39(PluralOperands o) {
  if (((o.n == o.n.truncateToDouble() && ((o.n >= 0 && o.n <= 1)))) ||
      ((o.n == o.n.truncateToDouble() && ((o.n >= 11 && o.n <= 99)))))
    return 'one';
  return 'other';
}

final _ordinalRules = <String, String Function(PluralOperands)>{
  'af': _ordinal0,
  'am': _ordinal0,
  'an': _ordinal0,
  'ar': _ordinal0,
  'ast': _ordinal0,
  'bg': _ordinal0,
  'bs': _ordinal0,
  'ce': _ordinal0,
  'cs': _ordinal0,
  'cv': _ordinal0,
  'da': _ordinal0,
  'de': _ordinal0,
  'dsb': _ordinal0,
  'el': _ordinal0,
  'es': _ordinal0,
  'et': _ordinal0,
  'eu': _ordinal0,
  'fa': _ordinal0,
  'fi': _ordinal0,
  'fy': _ordinal0,
  'gl': _ordinal0,
  'gsw': _ordinal0,
  'he': _ordinal0,
  'hr': _ordinal0,
  'hsb': _ordinal0,
  'ia': _ordinal0,
  'id': _ordinal0,
  'ie': _ordinal0,
  'is': _ordinal0,
  'ja': _ordinal0,
  'km': _ordinal0,
  'kn': _ordinal0,
  'ko': _ordinal0,
  'ky': _ordinal0,
  'lt': _ordinal0,
  'lv': _ordinal0,
  'ml': _ordinal0,
  'mn': _ordinal0,
  'my': _ordinal0,
  'nb': _ordinal0,
  'nl': _ordinal0,
  'no': _ordinal0,
  'pa': _ordinal0,
  'pl': _ordinal0,
  'prg': _ordinal0,
  'ps': _ordinal0,
  'pt': _ordinal0,
  'ru': _ordinal0,
  'sd': _ordinal0,
  'sh': _ordinal0,
  'si': _ordinal0,
  'sk': _ordinal0,
  'sl': _ordinal0,
  'sr': _ordinal0,
  'sw': _ordinal0,
  'ta': _ordinal0,
  'te': _ordinal0,
  'th': _ordinal0,
  'tpi': _ordinal0,
  'tr': _ordinal0,
  'und': _ordinal0,
  'ur': _ordinal0,
  'uz': _ordinal0,
  'yue': _ordinal0,
  'zh': _ordinal0,
  'zu': _ordinal0,
  'as': _ordinal1,
  'bn': _ordinal1,
  'az': _ordinal2,
  'bal': _ordinal3,
  'fil': _ordinal3,
  'fr': _ordinal3,
  'ga': _ordinal3,
  'hy': _ordinal3,
  'lo': _ordinal3,
  'mo': _ordinal3,
  'ms': _ordinal3,
  'ro': _ordinal3,
  'tl': _ordinal3,
  'vi': _ordinal3,
  'be': _ordinal4,
  'blo': _ordinal5,
  'ca': _ordinal6,
  'cy': _ordinal7,
  'en': _ordinal8,
  'gd': _ordinal9,
  'gu': _ordinal10,
  'hi': _ordinal10,
  'hu': _ordinal11,
  'it': _ordinal12,
  'lld': _ordinal12,
  'sc': _ordinal12,
  'vec': _ordinal12,
  'ka': _ordinal13,
  'kk': _ordinal14,
  'kok': _ordinal15,
  'kok-Latn': _ordinal15,
  'mr': _ordinal15,
  'kw': _ordinal16,
  'lij': _ordinal17,
  'scn': _ordinal17,
  'mk': _ordinal18,
  'ne': _ordinal19,
  'or': _ordinal20,
  'sq': _ordinal21,
  'sv': _ordinal22,
  'tk': _ordinal23,
  'uk': _ordinal24,
};
String _ordinal0(PluralOperands o) {
  return 'other';
}

String _ordinal1(PluralOperands o) {
  if (((o.n == 1 || o.n == 5 || o.n == 7 || o.n == 8 || o.n == 9 || o.n == 10)))
    return 'one';
  if (((o.n == 2 || o.n == 3))) return 'two';
  if (((o.n == 4))) return 'few';
  if (((o.n == 6))) return 'many';
  return 'other';
}

String _ordinal2(PluralOperands o) {
  if ((((o.i % 10) == 1 ||
          (o.i % 10) == 2 ||
          (o.i % 10) == 5 ||
          (o.i % 10) == 7 ||
          (o.i % 10) == 8)) ||
      (((o.i % 100) == 20 ||
          (o.i % 100) == 50 ||
          (o.i % 100) == 70 ||
          (o.i % 100) == 80)))
    return 'one';
  if ((((o.i % 10) == 3 || (o.i % 10) == 4)) ||
      (((o.i % 1000) == 100 ||
          (o.i % 1000) == 200 ||
          (o.i % 1000) == 300 ||
          (o.i % 1000) == 400 ||
          (o.i % 1000) == 500 ||
          (o.i % 1000) == 600 ||
          (o.i % 1000) == 700 ||
          (o.i % 1000) == 800 ||
          (o.i % 1000) == 900)))
    return 'few';
  if (((o.i == 0)) ||
      (((o.i % 10) == 6)) ||
      (((o.i % 100) == 40 || (o.i % 100) == 60 || (o.i % 100) == 90)))
    return 'many';
  return 'other';
}

String _ordinal3(PluralOperands o) {
  if (((o.n == 1))) return 'one';
  return 'other';
}

String _ordinal4(PluralOperands o) {
  if ((((o.n % 10) == 2 || (o.n % 10) == 3) &&
      !((o.n % 100) == 12 || (o.n % 100) == 13)))
    return 'few';
  return 'other';
}

String _ordinal5(PluralOperands o) {
  if (((o.i == 0))) return 'zero';
  if (((o.i == 1))) return 'one';
  if (((o.i == 2 || o.i == 3 || o.i == 4 || o.i == 5 || o.i == 6)))
    return 'few';
  return 'other';
}

String _ordinal6(PluralOperands o) {
  if (((o.n == 1 || o.n == 3))) return 'one';
  if (((o.n == 2))) return 'two';
  if (((o.n == 4))) return 'few';
  return 'other';
}

String _ordinal7(PluralOperands o) {
  if (((o.n == 0 || o.n == 7 || o.n == 8 || o.n == 9))) return 'zero';
  if (((o.n == 1))) return 'one';
  if (((o.n == 2))) return 'two';
  if (((o.n == 3 || o.n == 4))) return 'few';
  if (((o.n == 5 || o.n == 6))) return 'many';
  return 'other';
}

String _ordinal8(PluralOperands o) {
  if ((((o.n % 10) == 1) && !((o.n % 100) == 11))) return 'one';
  if ((((o.n % 10) == 2) && !((o.n % 100) == 12))) return 'two';
  if ((((o.n % 10) == 3) && !((o.n % 100) == 13))) return 'few';
  return 'other';
}

String _ordinal9(PluralOperands o) {
  if (((o.n == 1 || o.n == 11))) return 'one';
  if (((o.n == 2 || o.n == 12))) return 'two';
  if (((o.n == 3 || o.n == 13))) return 'few';
  return 'other';
}

String _ordinal10(PluralOperands o) {
  if (((o.n == 1))) return 'one';
  if (((o.n == 2 || o.n == 3))) return 'two';
  if (((o.n == 4))) return 'few';
  if (((o.n == 6))) return 'many';
  return 'other';
}

String _ordinal11(PluralOperands o) {
  if (((o.n == 1 || o.n == 5))) return 'one';
  return 'other';
}

String _ordinal12(PluralOperands o) {
  if (((o.n == 11 || o.n == 8 || o.n == 80 || o.n == 800))) return 'many';
  return 'other';
}

String _ordinal13(PluralOperands o) {
  if (((o.i == 1))) return 'one';
  if (((o.i == 0)) ||
      (((o.i % 100) == (o.i % 100).truncateToDouble() &&
          (((o.i % 100) >= 2 && (o.i % 100) <= 20) ||
              (o.i % 100) == 40 ||
              (o.i % 100) == 60 ||
              (o.i % 100) == 80))))
    return 'many';
  return 'other';
}

String _ordinal14(PluralOperands o) {
  if ((((o.n % 10) == 6)) ||
      (((o.n % 10) == 9)) ||
      (((o.n % 10) == 0) && !(o.n == 0)))
    return 'many';
  return 'other';
}

String _ordinal15(PluralOperands o) {
  if (((o.n == 1))) return 'one';
  if (((o.n == 2 || o.n == 3))) return 'two';
  if (((o.n == 4))) return 'few';
  return 'other';
}

String _ordinal16(PluralOperands o) {
  if (((o.n == o.n.truncateToDouble() && ((o.n >= 1 && o.n <= 4)))) ||
      (((o.n % 100) == (o.n % 100).truncateToDouble() &&
          (((o.n % 100) >= 1 && (o.n % 100) <= 4) ||
              ((o.n % 100) >= 21 && (o.n % 100) <= 24) ||
              ((o.n % 100) >= 41 && (o.n % 100) <= 44) ||
              ((o.n % 100) >= 61 && (o.n % 100) <= 64) ||
              ((o.n % 100) >= 81 && (o.n % 100) <= 84)))))
    return 'one';
  if (((o.n == 5)) || (((o.n % 100) == 5))) return 'many';
  return 'other';
}

String _ordinal17(PluralOperands o) {
  if (((o.n == o.n.truncateToDouble() &&
      (o.n == 11 ||
          o.n == 8 ||
          (o.n >= 80 && o.n <= 89) ||
          (o.n >= 800 && o.n <= 899)))))
    return 'many';
  return 'other';
}

String _ordinal18(PluralOperands o) {
  if ((((o.i % 10) == 1) && !((o.i % 100) == 11))) return 'one';
  if ((((o.i % 10) == 2) && !((o.i % 100) == 12))) return 'two';
  if ((((o.i % 10) == 7 || (o.i % 10) == 8) &&
      !((o.i % 100) == 17 || (o.i % 100) == 18)))
    return 'many';
  return 'other';
}

String _ordinal19(PluralOperands o) {
  if (((o.n == o.n.truncateToDouble() && ((o.n >= 1 && o.n <= 4)))))
    return 'one';
  return 'other';
}

String _ordinal20(PluralOperands o) {
  if (((o.n == o.n.truncateToDouble() &&
      (o.n == 1 || o.n == 5 || (o.n >= 7 && o.n <= 9)))))
    return 'one';
  if (((o.n == 2 || o.n == 3))) return 'two';
  if (((o.n == 4))) return 'few';
  if (((o.n == 6))) return 'many';
  return 'other';
}

String _ordinal21(PluralOperands o) {
  if (((o.n == 1))) return 'one';
  if ((((o.n % 10) == 4) && !((o.n % 100) == 14))) return 'many';
  return 'other';
}

String _ordinal22(PluralOperands o) {
  if ((((o.n % 10) == 1 || (o.n % 10) == 2) &&
      !((o.n % 100) == 11 || (o.n % 100) == 12)))
    return 'one';
  return 'other';
}

String _ordinal23(PluralOperands o) {
  if ((((o.n % 10) == 6 || (o.n % 10) == 9)) || ((o.n == 10))) return 'few';
  return 'other';
}

String _ordinal24(PluralOperands o) {
  if ((((o.n % 10) == 3) && !((o.n % 100) == 13))) return 'few';
  return 'other';
}

const _cldrAliases = <String, String>{
  'aa-saaho': 'ssy',
  'aam': 'aas',
  'aar': 'aa',
  'abk': 'ab',
  'adp': 'dz',
  'afr': 'af',
  'agp': 'apf',
  'ais': 'ami',
  'ajp': 'apc',
  'ajt': 'aeb',
  'aju': 'jrb',
  'aka': 'ak',
  'alb': 'sq',
  'als': 'sq',
  'amh': 'am',
  'ara': 'ar',
  'arb': 'ar',
  'arg': 'an',
  'arm': 'hy',
  'art-lojban': 'jbo',
  'asd': 'snz',
  'asm': 'as',
  'aue': 'ktz',
  'ava': 'av',
  'ave': 'ae',
  'aym': 'ay',
  'ayr': 'ay',
  'ayx': 'nun',
  'aze': 'az',
  'azj': 'az',
  'bak': 'ba',
  'bam': 'bm',
  'baq': 'eu',
  'baz': 'nvo',
  'bcc': 'bal',
  'bcl': 'bik',
  'bel': 'be',
  'ben': 'bn',
  'bgm': 'bcg',
  'bh': 'bho',
  'bhk': 'fbl',
  'bic': 'bir',
  'bih': 'bho',
  'bis': 'bi',
  'bjd': 'drl',
  'bjq': 'bzc',
  'bkb': 'ebk',
  'blg': 'iba',
  'bod': 'bo',
  'bos': 'bs',
  'bre': 'br',
  'btb': 'beb',
  'bul': 'bg',
  'bur': 'my',
  'bxk': 'luy',
  'bxr': 'bua',
  'cat': 'ca',
  'ccq': 'rki',
  'cel-gaulish': 'xtg',
  'ces': 'cs',
  'cha': 'ch',
  'che': 'ce',
  'chi': 'zh',
  'chu': 'cu',
  'chv': 'cv',
  'cjr': 'mom',
  'cka': 'cmr',
  'cld': 'syr',
  'cls': 'sa',
  'cmk': 'xch',
  'cmn': 'zh',
  'cnr': 'sr-ME',
  'cor': 'kw',
  'cos': 'co',
  'coy': 'pij',
  'cqu': 'quh',
  'cre': 'cr',
  'cwd': 'cr',
  'cym': 'cy',
  'cze': 'cs',
  'daf': 'dnj',
  'dan': 'da',
  'dap': 'njz',
  'dek': 'sqm',
  'deu': 'de',
  'dgo': 'doi',
  'dhd': 'mwr',
  'dik': 'din',
  'diq': 'zza',
  'dit': 'dif',
  'div': 'dv',
  'djl': 'dze',
  'dkl': 'aqd',
  'drh': 'mn',
  'drr': 'kzk',
  'drw': 'fa-AF',
  'dud': 'uth',
  'duj': 'dwu',
  'dut': 'nl',
  'dwl': 'dbt',
  'dzo': 'dz',
  'ekk': 'et',
  'ell': 'el',
  'elp': 'amq',
  'emk': 'man',
  'en-GB-oed': 'en-GB-oxendict',
  'eng': 'en',
  'epo': 'eo',
  'esk': 'ik',
  'est': 'et',
  'eus': 'eu',
  'ewe': 'ee',
  'fao': 'fo',
  'fas': 'fa',
  'fat': 'ak',
  'fij': 'fj',
  'fin': 'fi',
  'fra': 'fr',
  'fre': 'fr',
  'fry': 'fy',
  'fuc': 'ff',
  'ful': 'ff',
  'gav': 'dev',
  'gaz': 'om',
  'gbc': 'wny',
  'gbo': 'grb',
  'geo': 'ka',
  'ger': 'de',
  'gfx': 'vaj',
  'ggn': 'gvr',
  'ggo': 'esg',
  'ggr': 'gtu',
  'gio': 'aou',
  'gla': 'gd',
  'gle': 'ga',
  'glg': 'gl',
  'gli': 'kzk',
  'glv': 'gv',
  'gno': 'gon',
  'gom': 'kok',
  'gre': 'el',
  'grn': 'gn',
  'gti': 'nyc',
  'gug': 'gn',
  'guj': 'gu',
  'guv': 'duz',
  'gya': 'gba',
  'hat': 'ht',
  'hau': 'ha',
  'hbs': 'sr-Latn',
  'hdn': 'hai',
  'hea': 'hmn',
  'heb': 'he',
  'her': 'hz',
  'him': 'srx',
  'hin': 'hi',
  'hmo': 'ho',
  'hrr': 'jal',
  'hrv': 'hr',
  'hun': 'hu',
  'hy-arevmda': 'hyw',
  'hye': 'hy',
  'i-ami': 'ami',
  'i-bnn': 'bnn',
  'i-default': 'en-x-i-default',
  'i-enochian': 'und-x-i-enochian',
  'i-hak': 'hak',
  'i-klingon': 'tlh',
  'i-lux': 'lb',
  'i-mingo': 'see-x-i-mingo',
  'i-navajo': 'nv',
  'i-pwn': 'pwn',
  'i-tao': 'tao',
  'i-tay': 'tay',
  'i-tsu': 'tsu',
  'ibi': 'opa',
  'ibo': 'ig',
  'ice': 'is',
  'ido': 'io',
  'iii': 'ii',
  'ike': 'iu',
  'iku': 'iu',
  'ile': 'ie',
  'ill': 'ilm',
  'ilw': 'gal',
  'in': 'id',
  'ina': 'ia',
  'ind': 'id',
  'ipk': 'ik',
  'isl': 'is',
  'ita': 'it',
  'iw': 'he',
  'izi': 'eza',
  'jar': 'jgk',
  'jav': 'jv',
  'jeg': 'oyb',
  'ji': 'yi',
  'jpn': 'ja',
  'jw': 'jv',
  'kal': 'kl',
  'kan': 'kn',
  'kas': 'ks',
  'kat': 'ka',
  'kau': 'kr',
  'kaz': 'kk',
  'kdv': 'zkd',
  'kgc': 'tdf',
  'kgd': 'ncq',
  'kgh': 'kml',
  'kgm': 'plu',
  'khk': 'mn',
  'khm': 'km',
  'kik': 'ki',
  'kin': 'rw',
  'kir': 'ky',
  'kmr': 'ku',
  'knc': 'kr',
  'kng': 'kg',
  'koj': 'kwv',
  'kom': 'kv',
  'kon': 'kg',
  'kor': 'ko',
  'kpp': 'jkm',
  'kpv': 'kv',
  'krm': 'bmf',
  'ktr': 'dtp',
  'kua': 'kj',
  'kur': 'ku',
  'kvs': 'gdj',
  'kwq': 'yam',
  'kxe': 'tvd',
  'kxl': 'kru',
  'kzh': 'dgl',
  'kzj': 'dtp',
  'kzt': 'dtp',
  'lak': 'ksp',
  'lao': 'lo',
  'lat': 'la',
  'lav': 'lv',
  'lbk': 'bnc',
  'leg': 'enl',
  'lii': 'raq',
  'lim': 'li',
  'lin': 'ln',
  'lit': 'lt',
  'llo': 'ngt',
  'lmm': 'rmx',
  'ltz': 'lb',
  'lub': 'lu',
  'lug': 'lg',
  'lvs': 'lv',
  'mac': 'mk',
  'mah': 'mh',
  'mal': 'ml',
  'mao': 'mi',
  'mar': 'mr',
  'may': 'ms',
  'meg': 'cir',
  'mgx': 'jbk',
  'mhr': 'chm',
  'mkd': 'mk',
  'mlg': 'mg',
  'mlt': 'mt',
  'mnt': 'wnn',
  'mo': 'ro',
  'mof': 'xnt',
  'mol': 'ro',
  'mon': 'mn',
  'mri': 'mi',
  'msa': 'ms',
  'mst': 'mry',
  'mup': 'raj',
  'mwd': 'dmw',
  'mwj': 'vaj',
  'mya': 'my',
  'myd': 'aog',
  'myt': 'mry',
  'nad': 'xny',
  'nau': 'na',
  'nav': 'nv',
  'nbf': 'nru',
  'nbl': 'nr',
  'nbx': 'gll',
  'ncp': 'kdz',
  'nde': 'nd',
  'ndo': 'ng',
  'nep': 'ne',
  'nld': 'nl',
  'nln': 'azd',
  'nlr': 'nrk',
  'nno': 'nn',
  'nns': 'nbr',
  'nnx': 'ngv',
  'no-bok': 'nb',
  'no-bokmal': 'nb',
  'no-nyn': 'nn',
  'no-nynorsk': 'nn',
  'nob': 'nb',
  'nom': 'cbr',
  'noo': 'dtd',
  'nor': 'no',
  'npi': 'ne',
  'nte': 'eko',
  'nts': 'pij',
  'nxu': 'bpp',
  'nya': 'ny',
  'oci': 'oc',
  'ojg': 'oj',
  'oji': 'oj',
  'ori': 'or',
  'orm': 'om',
  'ory': 'or',
  'oss': 'os',
  'oun': 'vaj',
  'pan': 'pa',
  'pat': 'kxr',
  'pbu': 'ps',
  'pcr': 'adx',
  'per': 'fa',
  'pes': 'fa',
  'pli': 'pi',
  'plt': 'mg',
  'pmc': 'huw',
  'pmk': 'crr',
  'pmu': 'phr',
  'pnb': 'lah',
  'pol': 'pl',
  'por': 'pt',
  'ppa': 'bfy',
  'ppr': 'lcq',
  'prp': 'gu',
  'prs': 'fa-AF',
  'pry': 'prt',
  'pus': 'ps',
  'puz': 'pub',
  'que': 'qu',
  'quz': 'qu',
  'rmr': 'emx',
  'rmy': 'rom',
  'roh': 'rm',
  'ron': 'ro',
  'rum': 'ro',
  'run': 'rn',
  'rus': 'ru',
  'sag': 'sg',
  'san': 'sa',
  'sap': 'aqt',
  'sca': 'hle',
  'scc': 'sr',
  'scr': 'hr',
  'sgl': 'isk',
  'sgn-BE-FR': 'sfb',
  'sgn-BE-NL': 'vgt',
  'sgn-BR': 'bzs',
  'sgn-CH-DE': 'sgg',
  'sgn-CO': 'csn',
  'sgn-DE': 'gsg',
  'sgn-DK': 'dsl',
  'sgn-ES': 'ssp',
  'sgn-FR': 'fsl',
  'sgn-GB': 'bfi',
  'sgn-GR': 'gss',
  'sgn-IE': 'isg',
  'sgn-IT': 'ise',
  'sgn-JP': 'jsl',
  'sgn-MX': 'mfs',
  'sgn-NI': 'ncs',
  'sgn-NL': 'dse',
  'sgn-NO': 'nsi',
  'sgn-PT': 'psr',
  'sgn-SE': 'swl',
  'sgn-US': 'ase',
  'sgn-ZA': 'sfs',
  'sh': 'sr-Latn',
  'sin': 'si',
  'skk': 'oyb',
  'slk': 'sk',
  'slo': 'sk',
  'slv': 'sl',
  'smd': 'kmb',
  'sme': 'se',
  'smo': 'sm',
  'sna': 'sn',
  'snb': 'iba',
  'snd': 'sd',
  'som': 'so',
  'sot': 'st',
  'spa': 'es',
  'spy': 'kln',
  'sqi': 'sq',
  'src': 'sc',
  'srd': 'sc',
  'srp': 'sr',
  'ssw': 'ss',
  'sul': 'sgd',
  'sum': 'ulw',
  'sun': 'su',
  'swa': 'sw',
  'swc': 'sw-CD',
  'swe': 'sv',
  'swh': 'sw',
  'szd': 'umi',
  'tah': 'ty',
  'tam': 'ta',
  'tat': 'tt',
  'tdu': 'dtp',
  'tel': 'te',
  'tgg': 'bjp',
  'tgk': 'tg',
  'tgl': 'fil',
  'tha': 'th',
  'thc': 'tpo',
  'thw': 'ola',
  'thx': 'oyb',
  'tib': 'bo',
  'tid': 'itd',
  'tie': 'ras',
  'tir': 'ti',
  'tkk': 'twm',
  'tl': 'fil',
  'tlw': 'weo',
  'tmk': 'tdg',
  'tmp': 'tyj',
  'tne': 'kak',
  'tnf': 'fa-AF',
  'ton': 'to',
  'tpw': 'tpn',
  'tsf': 'taj',
  'tsn': 'tn',
  'tso': 'ts',
  'ttq': 'tmh',
  'tuk': 'tk',
  'tur': 'tr',
  'tw': 'ak',
  'twi': 'ak',
  'uig': 'ug',
  'ukr': 'uk',
  'umu': 'del',
  'und-aaland': 'und-AX',
  'und-arevela': 'und',
  'und-arevmda': 'und',
  'und-bokmal': 'und',
  'und-hakka': 'und',
  'und-hepburn-heploc': 'und-alalc97',
  'und-lojban': 'und',
  'und-nynorsk': 'und',
  'und-saaho': 'und',
  'und-xiang': 'und',
  'unp': 'wro',
  'uok': 'ema',
  'urd': 'ur',
  'uzb': 'uz',
  'uzn': 'uz',
  'ven': 've',
  'vie': 'vi',
  'vol': 'vo',
  'wel': 'cy',
  'wgw': 'wgb',
  'wit': 'nol',
  'wiw': 'nwo',
  'wln': 'wa',
  'wol': 'wo',
  'xba': 'cax',
  'xho': 'xh',
  'xia': 'acn',
  'xkh': 'waw',
  'xpe': 'kpe',
  'xrq': 'dmw',
  'xsj': 'suj',
  'xsl': 'den',
  'xss': 'zko',
  'ybd': 'rki',
  'ydd': 'yi',
  'yen': 'ynq',
  'yid': 'yi',
  'yiy': 'yrm',
  'yma': 'lrr',
  'ymt': 'mtm',
  'yor': 'yo',
  'yos': 'zom',
  'yuu': 'yug',
  'zai': 'zap',
  'zh-cmn': 'zh',
  'zh-cmn-Hans': 'zh-Hans',
  'zh-cmn-Hant': 'zh-Hant',
  'zh-gan': 'gan',
  'zh-guoyu': 'zh',
  'zh-hakka': 'hak',
  'zh-min': 'nan-x-zh-min',
  'zh-min-nan': 'nan',
  'zh-wuu': 'wuu',
  'zh-xiang': 'hsn',
  'zh-yue': 'yue',
  'zha': 'za',
  'zho': 'zh',
  'zir': 'scv',
  'zkb': 'kjh',
  'zsm': 'ms',
  'zul': 'zu',
  'zyb': 'za',
};
