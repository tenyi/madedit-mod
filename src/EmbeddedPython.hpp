///////////////////////////////////////////////////////////////////////////////
// Name:		EmbeddedPython.hpp
// Description:
// Author:		minggang.li@gmail.com
// Licence: 	GPL
///////////////////////////////////////////////////////////////////////////////

#ifndef __EMBEDDEDPYTHON__
#define __EMBEDDEDPYTHON__

#include <Python.h>

// Boost.Python 是以靜態方式編進本程式的，必須宣告成 static lib，
// 否則 BOOST_PYTHON_DECL 會被展開成 __declspec(dllimport)。
// 若建置系統已經用 -D 定義過，就不要重複定義。
#ifndef BOOST_PYTHON_STATIC_LIB
	#define BOOST_PYTHON_STATIC_LIB
#endif
#include "../python/include/boost/python.hpp"

#include <functional>
#include <iostream>
#include <string>
#include <memory>

// 原本用 __cplusplus 判斷 C++17 才把 auto_ptr 別名成 unique_ptr，
// 但 MSVC 沒加 /Zc:__cplusplus 時 __cplusplus 永遠是 199711L，會誤用已移除的 std::auto_ptr。
// 現在所有平台都至少是 C++17，直接用 std::unique_ptr（Boost.Python 的 make_constructor 支援）。

namespace py = ::boost::python;

extern void PrintString(const std::string& str);
namespace embedded_python {

	enum direction_type
	{
		STDIN,
		STDOUT,
		STDERR
	};

	template<direction_type>
	class py_redirector
	{
	public:
		py_redirector()
		{ }

		explicit py_redirector(std::function<void (const std::string&)> f)
			: m_write_fn(f)
		{ }

		void write(const std::string& text) {
			if (m_write_fn)
			{ m_write_fn(text); }
			else
			{ std::cout << text; }
		}

	public:
		std::function<void (const std::string&)> m_write_fn;
	};

	typedef py_redirector<STDOUT>   stdout_redirector;
	typedef py_redirector<STDERR>   stderr_redirector;


	static std::unique_ptr<stdout_redirector> make_stdout_redirector()
	{
		std::unique_ptr<stdout_redirector> ptr(new stdout_redirector(PrintString));
		return ptr;
	}

	static std::unique_ptr<stderr_redirector> make_stderr_redirector()
	{
		std::unique_ptr<stderr_redirector> ptr(new stderr_redirector(PrintString));
		return ptr;
	}
}

class EmbeddedPython
{
public:
	EmbeddedPython();

	~EmbeddedPython() {
		// Boost.Python doesn't support Py_Finalize yet, so don't call it!
		//Py_Finalize();
	}

	void exec(const std::string& command) {
		try {
			py::object result = py::exec(command.c_str(),
			                              m_main_global, m_main_global);
		}
		catch(const py::error_already_set&) {
			if (PyErr_Occurred()) {
				PyErr_Print();
				PyErr_Clear();
			}
			else {
				std::cerr << "A C++ exception was thrown for which "
				          << "there was no exception handler registered.\n";
			}
		}
	}

	void write_stdout(const std::string& text) {
		std::cout << ">>> " << text;
	}

	void write_stderr(const std::string& text) {
		std::cout << "xxx " << text;
	}

private:
	py::object m_main_module;
	py::dict   m_main_global;
};

extern EmbeddedPython * g_EmbeddedPython;
#endif //__EMBEDDEDPYTHON__

