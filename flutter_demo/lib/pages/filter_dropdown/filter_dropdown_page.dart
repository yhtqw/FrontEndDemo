import 'package:flutter/material.dart';

import 'widgets/filter_dropdown/filter_dropdown.dart';
import 'widgets/filter_dropdown/models/filter_dropdown_option_model.dart';
import 'widgets/filter_dropdown/models/options_container_prop_model.dart';

class FilterDropdownPage extends StatefulWidget {
  const FilterDropdownPage({super.key});

  static final String routePath = '/filter-dropdown';

  @override
  State<FilterDropdownPage> createState() => _FilterDropdownPageState();
}

class _FilterDropdownPageState extends State<FilterDropdownPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('可过滤的下拉选择框'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            SizedBox(height: 20,),

            FilterDropdown(
              items: [
                FilterDropdownOptionModel(text: '香蕉', type: 1),
                FilterDropdownOptionModel(text: '苹果', type: 2),
                FilterDropdownOptionModel(text: '鸭梨', type: 3),
                FilterDropdownOptionModel(text: '橘子', type: 4),
                FilterDropdownOptionModel(text: '百香果', type: 5),
                FilterDropdownOptionModel(text: '甘蔗', type: 6),
                FilterDropdownOptionModel(text: '葡萄', type: 7),
                FilterDropdownOptionModel(text: '芒果', type: 8),
                FilterDropdownOptionModel(text: '火龙果', type: 9),
                FilterDropdownOptionModel(text: '柠檬', type: 10),
              ],
              useCustomize: true,
              onSelected: (item) {
                print('当前选中的项是：${item.text}');
              },
              containerBgColor: Color(0xFFF0F0F0),
              containerHeight: 60,
              containerBorderRadius: BorderRadius.circular(30),
              containerPadding: EdgeInsets.only(left: 20),
              hintText: '请输入...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textStyle: TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
              cursorColor: Colors.blueAccent,
              optionsMarginTop: 10,
              optionsContainerProp: OptionsContainerPropModel(
                optionsBorderRadius: BorderRadius.circular(30),
                optionsMinHeight: 60,
                optionsMaxHeight: 350,
                optionsPadding: EdgeInsets.all(20),
                optionsBgColor: Color(0xFFF0F0F0),
              ),
              buildOption: (item) => Container(
                height: 35,
                margin: EdgeInsets.only(top: 5, bottom: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Color(0xFFFFFFFF),
                ),
                child: Text(
                  item.text,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // onFilter: (text) {
              //   return true;
              // },
            ),

            SizedBox(height: 20,),
            Text('这是下面的布局'),
            Text('这是下面的布局'),
            Text('这是下面的布局'),
            Text('这是下面的布局'),
            Text('这是下面的布局'),
            Text('这是下面的布局'),
            Text('这是下面的布局'),
            Text('这是下面的布局'),
            Text('这是下面的布局'),
          ],
        ),
      )
    );
  }
}
