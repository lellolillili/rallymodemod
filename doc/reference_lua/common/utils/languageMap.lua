-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- language lookup tables used for various things

local M = {}

-- ISO 3166-1 list
M.countries = {
    ['AF'] = 'Afghanistan',
    ['AX'] = 'Aland Islands',
    ['AL'] = 'Albania',
    ['DZ'] = 'Algeria',
    ['AS'] = 'American Samoa',
    ['AD'] = 'Andorra',
    ['AO'] = 'Angola',
    ['AI'] = 'Anguilla',
    ['AQ'] = 'Antarctica',
    ['AG'] = 'Antigua And Barbuda',
    ['AR'] = 'Argentina',
    ['AM'] = 'Armenia',
    ['AW'] = 'Aruba',
    ['AU'] = 'Australia',
    ['AT'] = 'Austria',
    ['AZ'] = 'Azerbaijan',
    ['BS'] = 'Bahamas',
    ['BH'] = 'Bahrain',
    ['BD'] = 'Bangladesh',
    ['BB'] = 'Barbados',
    ['BY'] = 'Belarus',
    ['BE'] = 'Belgium',
    ['BZ'] = 'Belize',
    ['BJ'] = 'Benin',
    ['BM'] = 'Bermuda',
    ['BT'] = 'Bhutan',
    ['BO'] = 'Bolivia',
    ['BA'] = 'Bosnia And Herzegovina',
    ['BW'] = 'Botswana',
    ['BV'] = 'Bouvet Island',
    ['BR'] = 'Brazil',
    ['IO'] = 'British Indian Ocean Territory',
    ['BN'] = 'Brunei Darussalam',
    ['BG'] = 'Bulgaria',
    ['BF'] = 'Burkina Faso',
    ['BI'] = 'Burundi',
    ['KH'] = 'Cambodia',
    ['CM'] = 'Cameroon',
    ['CA'] = 'Canada',
    ['CV'] = 'Cape Verde',
    ['KY'] = 'Cayman Islands',
    ['CF'] = 'Central African Republic',
    ['TD'] = 'Chad',
    ['CL'] = 'Chile',
    ['CN'] = 'China',
    ['CX'] = 'Christmas Island',
    ['CC'] = 'Cocos (Keeling) Islands',
    ['CO'] = 'Colombia',
    ['KM'] = 'Comoros',
    ['CG'] = 'Congo',
    ['CD'] = 'Congo, Democratic Republic',
    ['CK'] = 'Cook Islands',
    ['CR'] = 'Costa Rica',
    ['CI'] = 'Cote D\'Ivoire',
    ['HR'] = 'Croatia',
    ['CU'] = 'Cuba',
    ['CY'] = 'Cyprus',
    ['CZ'] = 'Czech Republic',
    ['DK'] = 'Denmark',
    ['DJ'] = 'Djibouti',
    ['DM'] = 'Dominica',
    ['DO'] = 'Dominican Republic',
    ['EC'] = 'Ecuador',
    ['EG'] = 'Egypt',
    ['SV'] = 'El Salvador',
    ['GQ'] = 'Equatorial Guinea',
    ['ER'] = 'Eritrea',
    ['EE'] = 'Estonia',
    ['ET'] = 'Ethiopia',
    ['FK'] = 'Falkland Islands (Malvinas)',
    ['FO'] = 'Faroe Islands',
    ['FJ'] = 'Fiji',
    ['FI'] = 'Finland',
    ['FR'] = 'France',
    ['GF'] = 'French Guiana',
    ['PF'] = 'French Polynesia',
    ['TF'] = 'French Southern Territories',
    ['GA'] = 'Gabon',
    ['GM'] = 'Gambia',
    ['GE'] = 'Georgia',
    ['DE'] = 'Germany',
    ['GH'] = 'Ghana',
    ['GI'] = 'Gibraltar',
    ['GR'] = 'Greece',
    ['GL'] = 'Greenland',
    ['GD'] = 'Grenada',
    ['GP'] = 'Guadeloupe',
    ['GU'] = 'Guam',
    ['GT'] = 'Guatemala',
    ['GG'] = 'Guernsey',
    ['GN'] = 'Guinea',
    ['GW'] = 'Guinea-Bissau',
    ['GY'] = 'Guyana',
    ['HT'] = 'Haiti',
    ['HM'] = 'Heard Island & Mcdonald Islands',
    ['VA'] = 'Holy See (Vatican City State)',
    ['HN'] = 'Honduras',
    ['HK'] = 'Hong Kong',
    ['HU'] = 'Hungary',
    ['IS'] = 'Iceland',
    ['IN'] = 'India',
    ['ID'] = 'Indonesia',
    ['IR'] = 'Iran, Islamic Republic Of',
    ['IQ'] = 'Iraq',
    ['IE'] = 'Ireland',
    ['IM'] = 'Isle Of Man',
    ['IL'] = 'Israel',
    ['IT'] = 'Italy',
    ['JM'] = 'Jamaica',
    ['JP'] = 'Japan',
    ['JE'] = 'Jersey',
    ['JO'] = 'Jordan',
    ['KZ'] = 'Kazakhstan',
    ['KE'] = 'Kenya',
    ['KI'] = 'Kiribati',
    ['KR'] = 'Korea',
    ['KW'] = 'Kuwait',
    ['KG'] = 'Kyrgyzstan',
    ['LA'] = 'Lao People\'s Democratic Republic',
    ['LV'] = 'Latvia',
    ['LB'] = 'Lebanon',
    ['LS'] = 'Lesotho',
    ['LR'] = 'Liberia',
    ['LY'] = 'Libyan Arab Jamahiriya',
    ['LI'] = 'Liechtenstein',
    ['LT'] = 'Lithuania',
    ['LU'] = 'Luxembourg',
    ['MO'] = 'Macao',
    ['MK'] = 'Macedonia',
    ['MG'] = 'Madagascar',
    ['MW'] = 'Malawi',
    ['MY'] = 'Malaysia',
    ['MV'] = 'Maldives',
    ['ML'] = 'Mali',
    ['MT'] = 'Malta',
    ['MH'] = 'Marshall Islands',
    ['MQ'] = 'Martinique',
    ['MR'] = 'Mauritania',
    ['MU'] = 'Mauritius',
    ['YT'] = 'Mayotte',
    ['MX'] = 'Mexico',
    ['FM'] = 'Micronesia, Federated States Of',
    ['MD'] = 'Moldova',
    ['MC'] = 'Monaco',
    ['MN'] = 'Mongolia',
    ['ME'] = 'Montenegro',
    ['MS'] = 'Montserrat',
    ['MA'] = 'Morocco',
    ['MZ'] = 'Mozambique',
    ['MM'] = 'Myanmar',
    ['NA'] = 'Namibia',
    ['NR'] = 'Nauru',
    ['NP'] = 'Nepal',
    ['NL'] = 'Netherlands',
    ['AN'] = 'Netherlands Antilles',
    ['NC'] = 'New Caledonia',
    ['NZ'] = 'New Zealand',
    ['NI'] = 'Nicaragua',
    ['NE'] = 'Niger',
    ['NG'] = 'Nigeria',
    ['NU'] = 'Niue',
    ['NF'] = 'Norfolk Island',
    ['MP'] = 'Northern Mariana Islands',
    ['NO'] = 'Norway',
    ['OM'] = 'Oman',
    ['PK'] = 'Pakistan',
    ['PW'] = 'Palau',
    ['PS'] = 'Palestinian Territory, Occupied',
    ['PA'] = 'Panama',
    ['PG'] = 'Papua New Guinea',
    ['PY'] = 'Paraguay',
    ['PE'] = 'Peru',
    ['PH'] = 'Philippines',
    ['PN'] = 'Pitcairn',
    ['PL'] = 'Poland',
    ['PT'] = 'Portugal',
    ['PR'] = 'Puerto Rico',
    ['QA'] = 'Qatar',
    ['RE'] = 'Reunion',
    ['RO'] = 'Romania',
    ['RU'] = 'Russian Federation',
    ['RW'] = 'Rwanda',
    ['BL'] = 'Saint Barthelemy',
    ['SH'] = 'Saint Helena',
    ['KN'] = 'Saint Kitts And Nevis',
    ['LC'] = 'Saint Lucia',
    ['MF'] = 'Saint Martin',
    ['PM'] = 'Saint Pierre And Miquelon',
    ['VC'] = 'Saint Vincent And Grenadines',
    ['WS'] = 'Samoa',
    ['SM'] = 'San Marino',
    ['ST'] = 'Sao Tome And Principe',
    ['SA'] = 'Saudi Arabia',
    ['SN'] = 'Senegal',
    ['RS'] = 'Serbia',
    ['SC'] = 'Seychelles',
    ['SL'] = 'Sierra Leone',
    ['SG'] = 'Singapore',
    ['SK'] = 'Slovakia',
    ['SI'] = 'Slovenia',
    ['SB'] = 'Solomon Islands',
    ['SO'] = 'Somalia',
    ['ZA'] = 'South Africa',
    ['GS'] = 'South Georgia And Sandwich Isl.',
    ['ES'] = 'Spain',
    ['LK'] = 'Sri Lanka',
    ['SD'] = 'Sudan',
    ['SR'] = 'Suriname',
    ['SJ'] = 'Svalbard And Jan Mayen',
    ['SZ'] = 'Swaziland',
    ['SE'] = 'Sweden',
    ['CH'] = 'Switzerland',
    ['SY'] = 'Syrian Arab Republic',
    ['TW'] = 'Taiwan',
    ['TJ'] = 'Tajikistan',
    ['TZ'] = 'Tanzania',
    ['TH'] = 'Thailand',
    ['TL'] = 'Timor-Leste',
    ['TG'] = 'Togo',
    ['TK'] = 'Tokelau',
    ['TO'] = 'Tonga',
    ['TT'] = 'Trinidad And Tobago',
    ['TN'] = 'Tunisia',
    ['TR'] = 'Turkey',
    ['TM'] = 'Turkmenistan',
    ['TC'] = 'Turks And Caicos Islands',
    ['TV'] = 'Tuvalu',
    ['UG'] = 'Uganda',
    ['UA'] = 'Ukraine',
    ['AE'] = 'United Arab Emirates',
    ['GB'] = 'United Kingdom',
    ['US'] = 'United States',
    ['UM'] = 'United States Outlying Islands',
    ['UY'] = 'Uruguay',
    ['UZ'] = 'Uzbekistan',
    ['VU'] = 'Vanuatu',
    ['VE'] = 'Venezuela',
    ['VN'] = 'Viet Nam',
    ['VG'] = 'Virgin Islands, British',
    ['VI'] = 'Virgin Islands, U.S.',
    ['WF'] = 'Wallis And Futuna',
    ['EH'] = 'Western Sahara',
    ['YE'] = 'Yemen',
    ['ZM'] = 'Zambia',
    ['ZW'] = 'Zimbabwe',
}

-- ISO 639-1 list
-- see https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
M.languages = {
    ['ab'] = 'Abkhazian',
    ['aa'] = 'Afar',
    ['af'] = 'Afrikaans',
    ['ak'] = 'Akan',
    ['sq'] = 'Albanian',
    ['am'] = 'Amharic',
    ['ar'] = 'Arabic',
    ['an'] = 'Aragonese',
    ['hy'] = 'Armenian',
    ['as'] = 'Assamese',
    ['av'] = 'Avaric',
    ['ae'] = 'Avestan',
    ['ay'] = 'Aymara',
    ['az'] = 'Azerbaijani',
    ['bm'] = 'Bambara',
    ['ba'] = 'Bashkir',
    ['eu'] = 'Basque',
    ['be'] = 'Belarusian',
    ['bn'] = 'Bengali',
    ['bh'] = 'Bihari languages',
    ['bi'] = 'Bislama',
    ['bs'] = 'Bosnian',
    ['br'] = 'Breton',
    ['bg'] = 'Bulgarian',
    ['my'] = 'Burmese',
    ['ca'] = 'Catalan, Valencian',
    ['km'] = 'Central Khmer',
    ['ch'] = 'Chamorro',
    ['ce'] = 'Chechen',
    ['ny'] = 'Chichewa, Chewa, Nyanja',
    ['zh'] = 'Chinese',
    ['cu'] = 'Church Slavonic, Old Bulgarian, Old Church Slavonic',
    ['cv'] = 'Chuvash',
    ['kw'] = 'Cornish',
    ['co'] = 'Corsican',
    ['cr'] = 'Cree',
    ['hr'] = 'Croatian',
    ['cs'] = 'Czech',
    ['da'] = 'Danish',
    ['dv'] = 'Divehi, Dhivehi, Maldivian',
    ['nl'] = 'Dutch, Flemish',
    ['dz'] = 'Dzongkha',
    ['en'] = 'English',
    ['eo'] = 'Esperanto',
    ['et'] = 'Estonian',
    ['ee'] = 'Ewe',
    ['fo'] = 'Faroese',
    ['fj'] = 'Fijian',
    ['fi'] = 'Finnish',
    ['fr'] = 'French',
    ['ff'] = 'Fulah',
    ['gd'] = 'Gaelic, Scottish Gaelic',
    ['gl'] = 'Galician',
    ['lg'] = 'Ganda',
    ['ka'] = 'Georgian',
    ['de'] = 'German',
    ['ki'] = 'Gikuyu, Kikuyu',
    ['el'] = 'Greek (Modern)',
    ['kl'] = 'Greenlandic, Kalaallisut',
    ['gn'] = 'Guarani',
    ['gu'] = 'Gujarati',
    ['ht'] = 'Haitian, Haitian Creole',
    ['ha'] = 'Hausa',
    ['he'] = 'Hebrew',
    ['hz'] = 'Herero',
    ['hi'] = 'Hindi',
    ['ho'] = 'Hiri Motu',
    ['hu'] = 'Hungarian',
    ['is'] = 'Icelandic',
    ['io'] = 'Ido',
    ['ig'] = 'Igbo',
    ['id'] = 'Indonesian',
    ['ia'] = 'Interlingua (International Auxiliary Language Association)',
    ['ie'] = 'Interlingue',
    ['iu'] = 'Inuktitut',
    ['ik'] = 'Inupiaq',
    ['ga'] = 'Irish',
    ['it'] = 'Italian',
    ['ja'] = 'Japanese',
    ['jv'] = 'Javanese',
    ['kn'] = 'Kannada',
    ['kr'] = 'Kanuri',
    ['ks'] = 'Kashmiri',
    ['kk'] = 'Kazakh',
    ['rw'] = 'Kinyarwanda',
    ['kv'] = 'Komi',
    ['kg'] = 'Kongo',
    ['ko'] = 'Korean',
    ['kj'] = 'Kwanyama, Kuanyama',
    ['ku'] = 'Kurdish',
    ['ky'] = 'Kyrgyz',
    ['lo'] = 'Lao',
    ['la'] = 'Latin',
    ['lv'] = 'Latvian',
    ['lb'] = 'Letzeburgesch, Luxembourgish',
    ['li'] = 'Limburgish, Limburgan, Limburger',
    ['ln'] = 'Lingala',
    ['lt'] = 'Lithuanian',
    ['lu'] = 'Luba-Katanga',
    ['mk'] = 'Macedonian',
    ['mg'] = 'Malagasy',
    ['ms'] = 'Malay',
    ['ml'] = 'Malayalam',
    ['mt'] = 'Maltese',
    ['gv'] = 'Manx',
    ['mi'] = 'Maori',
    ['mr'] = 'Marathi',
    ['mh'] = 'Marshallese',
    ['ro'] = 'Moldovan, Moldavian, Romanian',
    ['mn'] = 'Mongolian',
    ['na'] = 'Nauru',
    ['nv'] = 'Navajo, Navaho',
    ['nd'] = 'Northern Ndebele',
    ['ng'] = 'Ndonga',
    ['ne'] = 'Nepali',
    ['se'] = 'Northern Sami',
    ['no'] = 'Norwegian',
    ['nb'] = 'Norwegian Bokmål',
    ['nn'] = 'Norwegian Nynorsk',
    ['ii'] = 'Nuosu, Sichuan Yi',
    ['oc'] = 'Occitan (post 1500)',
    ['oj'] = 'Ojibwa',
    ['or'] = 'Oriya',
    ['om'] = 'Oromo',
    ['os'] = 'Ossetian, Ossetic',
    ['pi'] = 'Pali',
    ['pa'] = 'Panjabi, Punjabi',
    ['ps'] = 'Pashto, Pushto',
    ['fa'] = 'Persian',
    ['pl'] = 'Polish',
    ['pt'] = 'Portuguese',
    ['qu'] = 'Quechua',
    ['rm'] = 'Romansh',
    ['rn'] = 'Rundi',
    ['ru'] = 'Russian',
    ['sm'] = 'Samoan',
    ['sg'] = 'Sango',
    ['sa'] = 'Sanskrit',
    ['sc'] = 'Sardinian',
    ['sr'] = 'Serbian',
    ['sn'] = 'Shona',
    ['sd'] = 'Sindhi',
    ['si'] = 'Sinhala, Sinhalese',
    ['sk'] = 'Slovak',
    ['sl'] = 'Slovenian',
    ['so'] = 'Somali',
    ['st'] = 'Sotho, Southern',
    ['nr'] = 'South Ndebele',
    ['es'] = 'Spanish, Castilian',
    ['su'] = 'Sundanese',
    ['sw'] = 'Swahili',
    ['ss'] = 'Swati',
    ['sv'] = 'Swedish',
    ['sla-Latn'] = 'Interslavic (Latin)',
    ['tl'] = 'Tagalog',
    ['ty'] = 'Tahitian',
    ['tg'] = 'Tajik',
    ['ta'] = 'Tamil',
    ['tt'] = 'Tatar',
    ['te'] = 'Telugu',
    ['th'] = 'Thai',
    ['bo'] = 'Tibetan',
    ['ti'] = 'Tigrinya',
    ['to'] = 'Tonga (Tonga Islands)',
    ['ts'] = 'Tsonga',
    ['tn'] = 'Tswana',
    ['tr'] = 'Turkish',
    ['tk'] = 'Turkmen',
    ['tw'] = 'Twi',
    ['ug'] = 'Uighur, Uyghur',
    ['uk'] = 'Ukrainian',
    ['ur'] = 'Urdu',
    ['uz'] = 'Uzbek',
    ['ve'] = 'Venda',
    ['vi'] = 'Vietnamese',
    ['vo'] = 'Volap_k',
    ['wa'] = 'Walloon',
    ['cy'] = 'Welsh',
    ['fy'] = 'Western Frisian',
    ['wo'] = 'Wolof',
    ['xh'] = 'Xhosa',
    ['yi'] = 'Yiddish',
    ['yo'] = 'Yoruba',
    ['za'] = 'Zhuang, Chuang',
    ['zu'] = 'Zulu',
}

-- codes extracted from weblate - the translation platform we use
-- ATTENTION: LOWER CASE KEYS ONLY!
M.weblateCodes = {
  ['li'] = 'Limburgish',
  ['tl'] = 'Tagalog',
  ['ur'] = 'Urdu',
  ['ur_pk'] = 'Urdu (Pakistan)',
  ['uz_latn'] = 'Uzbek (latin)',
  ['uz'] = 'Uzbek',
  ['bs_latn'] = 'Bosnian (latin)',
  ['bs_cyrl'] = 'Bosnian (cyrillic)',
  ['sr_latn'] = 'Serbian (latin)',
  ['sr_cyrl'] = 'Serbian (cyrillic)',
  ['be_latn'] = 'Belarusian (latin)',
  ['en_us'] = 'English (United States)',
  ['en_ca'] = 'English (Canada)',
  ['en_au'] = 'English (Australia)',
  ['en_ie'] = 'English (Ireland)',
  ['en_ph'] = 'English (Philippines)',
  ['nb_no'] = 'Norwegian Bokmål',
  ['pt_pt'] = 'Portuguese (Portugal)',
  ['ckb'] = 'Kurdish Sorani',
  ['vls'] = 'West Flemish',
  ['zh'] = 'Chinese',
  ['tlh'] = 'Klingon',
  ['tlh_qaak'] = 'Klingon (pIqaD)',
  ['ksh'] = 'Colognian',
  ['sc'] = 'Sardinian',
  ['tr'] = 'Turkish',
  ['ach'] = 'Acholi',
  ['anp'] = 'Angika',
  ['as'] = 'Assamese',
  ['ay'] = 'Aymará',
  ['brx'] = 'Bodo',
  ['cgg'] = 'Chiga',
  ['doi'] = 'Dogri',
  ['es_ar'] = 'Spanish (Argentina)',
  ['es_mx'] = 'Spanish (Mexico)',
  ['es_pr'] = 'Spanish (Puerto Rico)',
  ['es_419'] = 'Spanish (Latin America)',
  ['es_us'] = 'Spanish (American)',
  ['hne'] = 'Chhattisgarhi',
  ['jbo'] = 'Lojban',
  ['kl'] = 'Greenlandic',
  ['mni'] = 'Manipuri',
  ['mnk'] = 'Mandinka',
  ['my'] = 'Burmese',
  ['se'] = 'Northern Sami',
  ['no'] = 'Norwegian (old code)',
  ['rw'] = 'Kinyarwanda',
  ['sat'] = 'Santali',
  ['sd'] = 'Sindhi',
  ['cy'] = 'Welsh',
  ['hy'] = 'Armenian',
  ['uz'] = 'Uzbek',
  ['os'] = 'Ossetian',
  ['ts'] = 'Tsonga',
  ['frp'] = 'Franco-Provençal',
  ['zh_hant'] = 'Chinese (Traditional)',
  ['zh_hans'] = 'Chinese (Simplified)',
  ['sh'] = 'Serbo-Croatian',
  ['nl_be'] = 'Dutch (Belgium)',
  ['ba'] = 'Bashkir',
  ['yi'] = 'Yiddish',
  ['de_at'] = 'Austrian German',
  ['de_ch'] = 'Swiss High German',
  ['nds'] = 'Low German',
  ['haw'] = 'Hawaiian',
  ['vec'] = 'Venetian',
  ['oj'] = 'Ojibwe',
  ['ch'] = 'Chamorro',
  ['chr'] = 'Cherokee',
  ['cr'] = 'Cree',
  ['ny'] = 'Nyanja',
  ['la'] = 'Latin',
  ['ar_dz'] = 'Arabic (Algeria)',
  ['ar_ma'] = 'Arabic (Morocco)',
  ['fr_ca'] = 'French (Canada)',
  ['kab'] = 'Kabyle',
  ['pr'] = 'Pirate',
  ['ig'] = 'Igbo',
  ['hsb'] = 'Upper Sorbian',
  ['sn'] = 'Shona',
  ['bar'] = 'Bavarian',
}

-- turns iso639-1 into long strings
local function resolve(key)
  local res = ''

  local kclean = string.lower(key):gsub('-', '_') -- replace - with _

  -- weblate special?
  if M.weblateCodes[kclean] then
    res = M.weblateCodes[kclean]
  else
    -- if not, decompose
    local lcomp = split(kclean, '_')
    if type(lcomp) ~= 'table' or #lcomp == 0 then
      return key
    end

    -- language first
    local codeOK = false
    if #lcomp > 0 and type(lcomp[1]) == 'string' then
      res = res .. (M.languages[lcomp[1]] or lcomp[1])
      codeOK = true
    end
    -- then country
    if #lcomp > 1 and type(lcomp[2]) == 'string' then
      res = res .. ' (' .. (M.countries[string.upper(lcomp[2])] or lcomp[2]) .. ')'
    end
  end

  --res = res .. ' [' .. tostring(key) .. ']'
  return res
end

M.resolve = resolve

return M