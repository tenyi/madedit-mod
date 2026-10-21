
/*
	Copyright (c) 2009 by Chad Nelson
	Released under the MIT License.
	See the provided LICENSE.TXT file for details.
*/

#ifndef MARKDOWN_H_INCLUDED
#define MARKDOWN_H_INCLUDED

#include <iostream>
#include <string>
#include <list>

#include <memory>
#include <unordered_map>

#include <boost/optional.hpp>

namespace markdown {

	using boost::optional;
	using boost::none;

	// Forward references.
	class Token;
	class LinkIds;

	typedef std::shared_ptr<Token> TokenPtr;
	typedef std::list<TokenPtr> TokenGroup;

	class Document {
		public:
		// 取代 boost::noncopyable：禁止複製（理由見下方 copy() 的說明）
		Document(const Document&) = delete;
		Document& operator=(const Document&) = delete;
		Document(size_t spacesPerTab=cDefaultSpacesPerTab);
		Document(std::wistream& in, size_t spacesPerTab=cDefaultSpacesPerTab);
		~Document();

		// You can call read() functions multiple times before writing if
		// desirable. Once the document has been processed for writing, it can't
		// accept any more input.
		bool read(const std::wstring&);
		bool read(std::wistream&);
		void write(std::wostream&);
		void writeTokens(std::wostream&); // For debugging

		// The class is marked noncopyable because it uses reference-counted
		// links to things that get changed during processing. If you want to
		// copy it, use the `copy` function to explicitly say that.
		Document copy() const; // TODO: Copy function not yet written.

		private:
		bool _getline(std::wistream& in, std::wstring& line);
		void _process();
		void _mergeMultilineHtmlTags();
		void _processInlineHtmlAndReferences();
		void _processBlocksItems(TokenPtr inTokenContainer);
		void _processParagraphLines(TokenPtr inTokenContainer);

		static const size_t cSpacesPerInitialTab, cDefaultSpacesPerTab;

		const size_t cSpacesPerTab;
		TokenPtr mTokenContainer;
		LinkIds *mIdTable;
		bool mProcessed;
	};

} // namespace markdown

#endif // MARKDOWN_H_INCLUDED
